clear all,close all,clc

debug = 1;
debug_multipath = 0;%�����Ƿ��Ƕྶ
debug_path_type = 16;%����ྶ����
SNR = [25];

%%��������
PN_total_len = 432; %֡ͷ����,ǰͬ��88����ͬ��89
DPN_total_len = 1024;
DPN_len = 512;
load pn256_pn512.mat
FFT_len = 3888*8; %֡�������FFT��IFFT����
Frame_len = PN_total_len + FFT_len; %֡��
sim_num= 1000; %�����֡��
iter_num = 3; %��������
MAX_CHANNEL_LEN = PN_total_len;

%%��ʵ�ŵ�
if debug_multipath
    channelFilter = multipath_new(debug_path_type,1/7.56,1,0);
    channel_real = zeros(1,PN_total_len);
    channel_real(1:length(channelFilter)) = channelFilter;
else
    channel_real = zeros(1,PN_total_len);
    channel_real(1) = 1;
end
channel_real_freq = fft(channel_real,FFT_len);

spn_start_measure_mse_frame = 50;
spn_end_measure_mse_frame = sim_num-9;
spn_h_freq_off_thresh = 0.02;
spn_h_denoise_alpha = 1/256;
spn_h_smooth_alpha = 1/4;
channel_estimate_spn = zeros(length(SNR),PN_total_len);

mse_pos = 1;
for SNR_IN = SNR %�������������
    %%��������
    close all;
    
    if debug_multipath
        matfilename = strcat('DTMB2_data_multipath_new',num2str(debug_path_type),'SNR',num2str(SNR_IN),'.mat');
        load(matfilename);
    else
        matfilename = strcat('DTMB2_data_awgn_SNR',num2str(SNR_IN),'.mat');
        load(matfilename);
    end
    
    %%��PN�ŵ�����,��������
    start_pos = 0;
    chan_len_spn = PN_total_len;
    last_frame_tail = zeros(1,chan_len_spn);
    frame_h_tps_delay = [];
    frame_h_tps_delay2 = [];
    frame_h_tps_delay3 = [];
    for i=1:sim_num-1
          close all;
          if debug || i == sim_num-1
              figure;
              plot(abs(channel_real));
              title('��ʵ�ŵ�����');
          end   
          
          Receive_data = Send_data_srrc_tx1_spn(start_pos+(1:Frame_len));
          pn_frame_temp = Receive_data(1:PN_total_len);
          pn_frame_temp(1:chan_len_spn) = pn_frame_temp(1:chan_len_spn)-last_frame_tail;
          
          %%TPS
          h_pn_conv = channel_pn_conv(PN, spn_h_smooth_result, chan_len_spn);                  
          frame_data_time =  Receive_data(PN_total_len+(1:FFT_len));
          pn_tail = h_pn_conv(PN_total_len+(1:chan_len_spn));
          data_tail =  Send_data_srrc_tx1_spn(start_pos+Frame_len+(1:chan_len_spn))-h_pn_conv(1:chan_len_spn);
          frame_data_recover =  frame_data_time;
          frame_data_recover(1:chan_len_spn)=frame_data_recover(1:chan_len_spn)-pn_tail+data_tail;
          frame_data_recover_freq = fft(frame_data_recover);
          
          channel_len_estimate_spn(mse_pos,i) = chan_len_spn;
          frame_h_tps_delay2 = frame_h_tps_delay;
          frame_h_tps_delay = h_frame_tps_current;
          
          %%���ݸ�������
          h_pn_conv = channel_pn_conv(PN, h_iter, chan_len_spn);
          spn_h_freq = fft(h_iter,FFT_len);                 
          frame_data_time =  Receive_data(PN_total_len+(1:FFT_len));
          pn_tail = h_pn_conv(PN_total_len+(1:chan_len_spn));
          data_tail =  Send_data_srrc_tx1_spn(start_pos+Frame_len+(1:chan_len_spn))-h_pn_conv(1:chan_len_spn);
          frame_data_recover =  frame_data_time;
          frame_data_recover(1:chan_len_spn)=frame_data_recover(1:chan_len_spn)-pn_tail+data_tail;
          
          %�ŵ����� mse
          spn_channel_mse(mse_pos,i) = norm(spn_h_smooth_result-channel_real)/norm(channel_real);
          
          %���㵱ǰ֡����β��������һ֡���������PN���Ƶ�Ӱ��
          frame_data_eq_freq = fft(frame_data_recover)./spn_h_freq;
          frame_data_eq_time = ifft(frame_data_eq_freq);
          frame_data_tail =  frame_data_eq_time(FFT_len-PN_total_len+(1:PN_total_len));
          data_tail_chan_conv = channel_pn_conv(frame_data_tail,spn_h_smooth_result, chan_len_spn);
          last_frame_tail = data_tail_chan_conv(PN_total_len+(1:chan_len_spn));
          
          %��ʵ�ŵ�����ʵ���ݵľ������ʱ���Ƶ����
          data_real_freq =  data_transfer((i-1)*FFT_len+(1:FFT_len)).*channel_real_freq;
          data_real_time = ifft(data_real_freq);

          spn_pn_rm_snr(mse_pos,i) = estimate_SNR(frame_data_recover,data_real_time);
          spn_temp = data_transfer((i-1)*FFT_len+(1:FFT_len)).*spn_h_freq;
          spn_chan_conv_snr(mse_pos,i) = estimate_SNR(spn_temp,data_real_freq);

          start_pos = start_pos + Frame_len;
    end
    spn_mean_mse(mse_pos) = mean(spn_channel_mse(mse_pos,spn_start_measure_mse_frame:spn_end_measure_mse_frame));
    spn_pnrm_SNR(mse_pos) = mean(spn_pn_rm_snr(mse_pos,spn_start_measure_mse_frame:spn_end_measure_mse_frame));
    spn_pn_chan_conv_freq_SNR(mse_pos) = mean(spn_chan_conv_snr(mse_pos,spn_start_measure_mse_frame:spn_end_measure_mse_frame));
    temp1 = 1/(10^(spn_pnrm_SNR(mse_pos)/10))+ 1/(10^(spn_pn_chan_conv_freq_SNR(mse_pos)/10));
    spn_ce_SNR(mse_pos) = 10*log10(1/temp1);
    mse_pos = mse_pos +1;
end
spn_mean_mse
spn_pnrm_SNR
spn_pn_chan_conv_freq_SNR
spn_ce_SNR

figure;
plot(abs(spn_h_smooth_result));
title('��PN�ŵ����ƽ��');

figure;
semilogy(SNR,spn_mean_mse,'r*-');
title('��PN����MSE');

figure;
plot(SNR,spn_pnrm_SNR,'r*-');
title('����ѭ���ع���������');

figure;
plot(SNR,spn_pn_chan_conv_freq_SNR,'r*-');
title('�ŵ��������������');