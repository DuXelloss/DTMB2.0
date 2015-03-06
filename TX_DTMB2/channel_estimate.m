function h_out = channel_estimate(data_in, PN, FFT_length,min_zeors_thresh)
%min_zeors_thresh ����С�ڴ˰ٷֱ���ֵ�ľ�����

 %%op1 �ŵ���ʱ��弤��Ӧ
 fft_PN_R = fft(data_in, FFT_length);
 fft_PN = fft(PN, FFT_length);
 H_F =  fft_PN_R./fft_PN;
      
%ƽ���˲�
freq_thres = 3.6;
mmse_weight = 0.99;

H_F(abs(fft_PN)<freq_thres)=0;
h_coarse = ifft(H_F);
h_mmse_filter = channel_mmse_filter(h_coarse, mmse_weight);
h_max = max(abs(h_mmse_filter));
h_out = h_mmse_filter.';
h_out(abs(h_out)<h_max*min_zeors_thresh )=0;
h_out(length(PN)+1:end)=0;


