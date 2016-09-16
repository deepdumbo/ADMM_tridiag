% test tridiag inpaint
if ~isvar('wavelets')
	wavelets = 1;
end
% ------ construct true image ------
if ~isvar('obj')
	obj = 'textbook';%'glass'; % 'textbook';
end
switch obj
case 'glass'
	fname = 'glass.png';
	xtrue = double(imread(fname));
	xtrue = xtrue(1:180, 1:270);
	xtrue = xtrue./max(xtrue(:));
case 'textbook'
	fname = 'textbook_contrast.jpg';
	xtrue = imread(fname);
	if size(xtrue, 3) > 1
		xtrue = rgb2gray(xtrue);
	end
	xtrue = double(xtrue);
	xtrue = downsample2(xtrue, 7);
	% make even dimensions
	if mod(size(xtrue, 1), 2) == 1
		xtrue = xtrue(2:end, :);
	end
	if mod(size(xtrue, 2), 2) == 1
		xtrue = xtrue(:, 2:end);
	end
	xtrue = xtrue(:,1:540);
	xtrue = xtrue./max(xtrue(:));
otherwise
	display('unknown obj option');
	keyboard
end
[Nx, Ny] = size(xtrue);

if ~isvar('reduce')
	reduce = 4;
end
if ~isvar('SNR')
	SNR = 20;
end
data_fname = sprintf('./inpainting_mat/%s/data_wavelet%d_SNR%d_reduce%d.mat', obj, wavelets, SNR, reduce);
if exist(data_fname, 'file')
	load(data_fname);
	display(sprintf('loaded data from file %s', data_fname))
else
	% ------ take measurements ------
	try
		rng(0);
	catch
		rand('state',0);
		randn('state',0);
	end
	samp = (rand(Nx, Ny) <= 1/reduce);
	D = Ginpaint(samp);
	[CH, CV] = construct_finite_diff([Nx Ny]);
	y_noiseless = D * xtrue;
	sig = 10^(-SNR/20) * norm(y_noiseless) / sqrt(length(y_noiseless));
	y = y_noiseless + sig*randn(size(y_noiseless));
	% ------ initialize x with nearest neighbors ------
	[xx, yy] = ndgrid(1:Nx, 1:Ny);
	xx_D = xx(samp);
	yy_D = yy(samp);
	xinit = griddata(xx_D, yy_D, y, xx, yy, 'nearest');
	save(data_fname, 'reduce', 'samp', 'D', 'CH', 'CV', 'SNR', 'y_noiseless', 'y', 'sig', 'xinit', 'xtrue');
end
% ------ construct regularizers ------- 
R = [CH; CV];
Rcirc = Cdiffs([Nx Ny],'offsets', [1 Nx], 'type_diff','circshift');
if wavelets
	W = Godwt1(true(Nx, Ny));
end
% ------ optimization params ------
niters = 2000;
mu0 = 1;
mu1 = 1;
mu2 = 1;
alph = 0.5;
alphw = 0.5;
% ------ regularization parameters for SNR = 20, reduce = 1.5 ------
beta_search_fname = sprintf('wavelet%d_SNR%d_reduce%1.2d.mat', wavelets, SNR, reduce);
d = dir(sprintf('inpainting_mat/%s', obj));
for ii = 1:length(d)
	if ~isempty(strfind(d(ii).name, beta_search_fname))
		load(d(ii).name, 'betas', 'betaws', 'betas_circ', 'betaws_circ');
	end
end
if ~isvar('betas')
	display(sprintf('no file found matching %s, if doing reg search no prob', beta_search_fname));
	keyboard
else
	beta = betas(ceil(length(betas)/2));
	betaw = betaws(ceil(length(betaws)/2));
	beta_circ = betas_circ(ceil(length(betas_circ)/2));
	betaw_circ = betaws_circ(ceil(length(betaws_circ)/2));
end
	%beta = 0.02743;
	%beta_circ = 0.02743;
	if isvar('jack_betas') && jack_betas
		beta = 0.2;
		betaw = 0.;
		beta_circ = 0.2;
		betaw_circ = 0.3;
	end

if wavelets
%       betaw = ??;
%       betaw_circ = ??;
	alphw = 0.5;
	CHW = [CH; betaw * alphw / beta * W];
	CVW = [CV; betaw * (1-alphw) / beta * W]; 
	RW = [CH; CV; betaw / beta * W];
	RcircW = [Rcirc; betaw_circ / beta_circ * W];
else        
	betaw = 0;
	CHW = CH; 
	CVW = CV; 
	RW = R; 
	RcircW = Rcirc;
end
								

% ------
% wavelets, CH, CV, R, Rcirc, RcircW, D, y, xinit, niters, mu0, mu1, mu2

curr_folder = sprintf('./inpainting_mat/%s/', obj);
slice_str = sprintf('wavelet%d_SNR%d_reduce%1.2d', wavelets, SNR, reduce);
if ~isvar('true_opt')
	true_opt = 'avg';%'inf'; % true
end


if ~alphw == 1
	MFISTA_inf_fname = sprintf('%s/x_MFISTA_inf_%s_beta%.*d.mat', curr_folder, slice_str, 3, beta);
else
	MFISTA_inf_fname = sprintf('%s/x_MFISTA_inf_%s_beta%.*d_%1.1dalphw.mat', curr_folder, slice_str, 3, beta, alphw);
end
ADMM_inf_fname = sprintf('%s/x_ADMM_inf_%s_beta%.*d_%1.1dalphw.mat', curr_folder, slice_str, 3, beta, alphw);
if strcmp(true_opt, 'inf') || strcmp(true_opt, 'avg') || strcmp(true_opt, 'ADMM')
	if exist(MFISTA_inf_fname, 'file')
		load(MFISTA_inf_fname, 'xMFIS');
		display(sprintf('loaded MFISTA inf from file %s', MFISTA_inf_fname));
	else
		display('no inf found')
		keyboard;
	end
	if exist(ADMM_inf_fname, 'file')
		load(ADMM_inf_fname, 'x*');
		if ~isvar('x_ADMM_inf') && isvar('x')
			x_ADMM_inf = reshape(x, Nx, Ny);
			clear x;
		end
		display(sprintf('loaded ADMM inf from file %s', ADMM_inf_fname));
	else
		display('no  ADMM inf found')
		keyboard;
	end

	if strcmp(true_opt, 'inf')
		xtrue = xMFIS;
	elseif strcmp(true_opt, 'ADMM')
		xtrue = x_ADMM_inf;
	elseif strcmp(true_opt, 'avg')
		xtrue = mean(cat(3, xMFIS, x_ADMM_inf),3);
	end
end
