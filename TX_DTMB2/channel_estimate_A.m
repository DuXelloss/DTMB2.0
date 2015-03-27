function h_out = channel_estimate_A(data_in, PN, FFT_length,debug)

 %%op1 �ŵ���ʱ��弤��Ӧ
 fft_PN_R = fft(data_in, FFT_length);
 fft_PN = fft(PN, FFT_length);
 H_F =  fft_PN_R./fft_PN;
 
%ƽ���˲�
freq_thres = max(abs(fft_PN))*0.001;
H_F(abs(fft_PN)<freq_thres)=0;
h_coarse = ifft(H_F);
mmse_weight = 0.99;
h_thresh = 0.01;
h_mmse_filter = channel_mmse_filter(h_coarse, mmse_weight);
h_out = h_mmse_filter.';
h_max = max(abs(h_out));
h_out(abs(h_out)>h_max*h_thresh)=h_coarse(abs(h_out)>h_max*h_thresh);
if debug
figure;
subplot(1,2,1);
plot(abs(h_coarse(1:length(PN))));
title('A:ԭʼ�ŵ����');
subplot(1,2,2);
plot(abs(h_mmse_filter(1:length(PN))));
title('A:mmse�˲����');
figure;
plot(abs(h_out(1:length(PN))));
title('A:������');
end
