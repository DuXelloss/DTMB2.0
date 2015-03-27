function h_out = channel_estimate_B(data_in, PN, FFT_length,debug)

 %%op1 �ŵ���ʱ��弤��Ӧ
 fft_PN_R = fft(data_in, FFT_length);
 fft_PN = fft(PN, FFT_length);
 H_F =  fft_PN_R./fft_PN;
 
%ƽ���˲�
freq_thres = max(abs(fft_PN))*0.001;
H_F(abs(fft_PN)<freq_thres)=0;
h_coarse = ifft(H_F);
h_out = h_coarse;
if debug
figure;
plot(abs(h_out(1:length(PN))));
title('B:�ŵ����ƽ��');
end
