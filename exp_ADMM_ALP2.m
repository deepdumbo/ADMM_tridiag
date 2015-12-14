% experimental data for SENSE_ADMM_ALP2



fn = './mai/static_SENSE_splitting/2010-07-06-fessler-3d/raw/p23040-3dspgr-8ch.7';
nc = 8;
[im4d,d] = recon3dft(fn,nc);
% what is d?
[body_coil_images,d] = recon3dft('./mai/static_SENSE_splitting/2010-07-06-fessler-3d/raw/p24064-3dspgr-body.7',1);
% slice = 38; % what sathish used 
% Muckley and Dan complained, so switch to 67
slice = 67;
mapped_im = squeeze(im4d(:,:,slice,:));
nx = size(im4d,1);
ny = size(im4d,2);


dims = [nx ny];

% need to esetimate sense maps for other slices
% for slice 67
load('mai/static_SENSE_splitting/saved_results/experimental/smap_est_slice_67.mat');
sense_maps = S_est;
clear S_est;


S = construct_sensefat(sense_maps);

reduction = 6;
samp = gen_poisson_sampling_pattern('2D',[nx ny],[ceil(nx/16) ceil(ny/16)],reduction);

% subsampling Fourier encoding matrix F
F = construct_fourierfat(samp,nc);

%for coil_ndx = 1:nc
%	y_full(:,:,coil_ndx) = fft2(imgs(:,:,coil_ndx)); 
%	if(dbug)
%	    im_test(:,:,coil_ndx) = ifft2(y_full(:,:,coil_ndx));
%	    y_full_test(:,:,coil_ndx) = fft2(imgs_test(:,:,coil_ndx));
%	end
%end
y = F*(mapped_im(:));


% compare to SoS solution
zero_fill = reshape(F'*y,nx,ny,nc)/(nx*ny);
SoS = sqrt(sum(zero_fill.^2,3));
%SoS = sqrt(sum(mapped_im.^2,3));

%figure; subplot(2,2,1); im(SoS);
%title('sum of squares solution');

% SoS derived in Fessler's office
SoS_compensate = sum(conj(sense_maps).*mapped_im,3)./(sum(abs(sense_maps).^2,3));

% finite-differencing matrices C1 and C2
[C1, C2] = construct_finite_diff(dims); % not circulant!
R = Cdiffs([nx ny],'type_diff','circshift'); %circulant!

% choose parameters

tri = 0;
triw = 1;
alp2 = 0;
alp2w = 0;

% beta, spatial regularization parameter
%betas = 2.^(13:0.5:15);%2^15.8
%beta = 0.52; % or beta = 5+; % for toy case
%beta = 2^14; % to match SoS compensate, for ALP2, reduction 3, up to 100 iters
%beta = 2^15.8; % to match body coil image, for ALP2, reduction 3
%betas = 2.^(18.5:.2:22);
beta = 2^20.1;
niters = 5000;
%niters = 100;

%for beta_ndx = 1:length(betas)
	%beta = betas(beta_ndx);

	% alpha, tradeoff between S
	alph = 0.5;
	%alph = 0;
	%alph = 1;
	% mu, convergence parameters
	mu = ones(1,5);

	%% 
	if tri
		[xhat_tri, xsaved_tri, nrmsd_tri, costOrig_tri, time_tri] = SENSE_ADMM_ALP2(y,F,S,C1,C2,alph,beta,mu,nx,ny,SoS,x_tri_inf,niters);
		xhat_tri = reshape(xhat_tri,nx,ny);
		scaling_SoS = normalize_images(SoS_compensate, {xhat_tri});
		scaling_bc = normalize_images(body_coil_images(:,:,slice), {xhat_tri});
		x_tri_inf = xhat_tri;
		x_tri_100 = xsaved_tri(:,:,100);
		save tri_chcv_5000iter.mat 
		save('x_tri_inf.mat','x_tri_inf');
		
		clear xsaved_tri xhat_tri nrmsd_tri costOrig_tri time_tri
		
	end
	if triw
		[xhat_triw, xsaved_triw, nrmsd_triw, costOrig_triw, time_triw] = SENSE_ADMM_ALP2_wavelets(y,F,S,C1,C2,alph,beta,mu,nx,ny,SoS,x_triw_inf,niters);
		xhat_triw = reshape(xhat_triw,nx,ny);
		scaling_SoS = normalize_images(SoS_compensate, {xhat_triw});
		scaling_bc = normalize_images(body_coil_images(:,:,slice), {xhat_triw});
		x_triw_inf = xhat_triw;
		x_triw_100 = xsaved_triw(:,:,100);
		save tri_wavelet_chcv_5000iter.mat
		save('x_triw_inf.mat','x_triw_inf');

		clear xsaved_triw xhat_triw nrmsd_triw costOrig_triw time_triw;
	end
	if alp2
		[xhat_alp2, xsaved_alp2, nrmsd_alp2, costOrig_alp2,time_alp2] = AL_P2_refurb(y,F,S,R,SoS,niters,beta,mu,nx,ny,x_alp2_inf);
		xhat_alp2 = reshape(xhat_alp2,nx,ny);
		scaling_SoS = normalize_images(SoS_compensate, {xhat_alp2});
		scaling_bc = normalize_images(body_coil_images(:,:,slice), {xhat_alp2});
		x_alp2_inf = xhat_alp2;
		x_alp2_100 = xsaved_alp2(:,:,100);
		save al_p2_rcirc_500iter.mat
		save('x_alp2_inf.mat','x_alp2_inf');
		clear xsaved_alp2 xhat_alp2 nrmsd_alp2 costOrig_alp2 time_alp2;
	end
	if alp2w
		[xhat_alp2w, xsaved_alp2w, nrmsd_alp2w, costOrig_alp2w,time_alp2w] = AL_P2_refurb_wavelets(y,F,S,R,SoS,niters,beta,mu,nx,ny,x_alp2w_inf);
		xhat_alp2w = reshape(xhat_alp2w,nx,ny);
		scaling_SoS = normalize_images(SoS_compensate, {xhat_alp2w});
		scaling_bc = normalize_images(body_coil_images(:,:,slice), {xhat_alp2w});
		x_alp2w_inf = xhat_alp2w;
		x_alp2w_100 = xsaved_alp2w(:,:,100);
		save al_p2_wavelet_rcirc_500iter.mat
		save('x_alp2w_inf.mat','x_alp2w_inf');
		clear xsaved_alp2w xhat_alp2w nrmsd_alp2w costOrig_alp2w time_alp2w;

	end
	%set(gca,'DataAspectRatio',[1.35 1 1]);

	%xsaved_beta_tri(:,:,beta_ndx) = reshape(xhat_tri,nx,ny);
	%xsaved_beta_triw(:,:,beta_ndx) = reshape(xhat_triw,nx,ny);
	%xsaved_beta_alp2(:,:,beta_ndx) = reshape(xhat_alp2,nx,ny);
%end

% RUN THIS BLOCK OF CODE TO FIND BEST BETA
%for beta_ndx = 1:length(betas)
%	curr_image = xsaved_beta_tri(:,:,beta_ndx);
%	scaling_SoS = normalize_images(SoS_compensate, {curr_image});
%	scaling_bc = normalize_images(body_coil_images(:,:,slice), {curr_image});
%	err_SoS(beta_ndx) = sqrt(sum(abs(col(scaling_SoS*curr_image-SoS_compensate)).^2));
%	err_bc(beta_ndx) = sqrt(sum(abs(col(scaling_bc*curr_image-body_coil_images(:,:,slice))).^2));
%end
return;
if alp2
	scaling_SoS = normalize_images(SoS_compensate, {xhat_alp2});
	scaling_bc = normalize_images(body_coil_images(:,:,slice), {xhat_alp2});
	figure; im([xhat_alp2*scaling_SoS SoS_compensate]);
	figure; im((xhat_alp2*scaling_SoS - SoS_compensate)/max(abs(col(SoS_compensate))));
	figure; im([xhat_alp2*scaling_bc body_coil_images(:,:,slice)]);
	figure; im((xhat_alp2*scaling_bc - body_coil_images(:,:,slice))/max(abs(col(body_coil_images(:,:,slice)))));
	figure; im(xsaved_alp2(:,:,1:200:end))

end
if alp2w

end
if tri
	scaling_SoS = normalize_images(SoS_compensate, {xhat_tri});
	scaling_bc = normalize_images(body_coil_images(:,:,slice), {xhat_tri});

	figure; im([xhat_tri*scaling_SoS SoS_compensate]);
	figure; im((xhat_tri*scaling_SoS - SoS_compensate)/max(abs(col(SoS_compensate))));
	figure; im([xhat_tri*scaling_bc body_coil_images(:,:,slice)]);
	figure; im((xhat_tri*scaling_bc - body_coil_images(:,:,slice))/max(abs(col(body_coil_images(:,:,slice)))));
end
if triw
	scaling_SoS = normalize_images(SoS_compensate, {xhat_triw});
	scaling_bc = normalize_images(body_coil_images(:,:,slice), {xhat_triw});
	figure; im([xhat_triw*scaling_SoS SoS_compensate]);
	figure; im((xhat_triw*scaling_SoS - SoS_compensate)/max(abs(col(SoS_compensate))));
	figure; im([xhat_triw*scaling_bc body_coil_images(:,:,slice)]);
	figure; im((xhat_triw*scaling_bc - body_coil_images(:,:,slice))/max(abs(col(body_coil_images(:,:,slice)))));

end
