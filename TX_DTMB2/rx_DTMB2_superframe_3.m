%%channel estimation 
%%���� 
%%���ݸ�������
%%DTMB2.0���ݷ��� ֡ͷ432��֡��3888*8��TPS 48,64QAM
%%����2
clear all,close all,clc
debug = 1;
debug_tps = 1;
SNR = [25];

spn_mean_mse = zeros(1,length(SNR));
dpn_mean_mse = zeros(1,length(SNR));
mse_pos = 1;
for SNR_IN = SNR %�������������
    
    %%��������
    debug_multipath = 1;%�����Ƿ��Ƕྶ
    debug_path_type = 1;%����ྶ����
    if debug_multipath
        matfilename = strcat('DTMB_data_multipath_new',num2str(debug_path_type),'SNR',num2str(SNR_IN),'.mat');
        load(matfilename);
    else
        load strcat('DTMB_data_awgn_SNR',num2str(SNR_IN),'.mat');
    end

    debug_frame_32k_eq = 1;%��������֡���ⳤ�ȣ�1Ϊ32K�� 0ΪFFT_Len

    %%��������
    PN_len = 255;  % PN ����
    PN_total_len = 432; %֡ͷ����,ǰͬ��88����ͬ��89
    DPN_total_len = 1024;
    DPN_len = 512;
    load pn256_pn512.mat
    PN_cyclic_Len = PN_total_len - PN_len;%֡ͷ��ѭ����չ�ĳ���
    PN_power = 3; %֡ͷ����dB
    FFT_len = 3888*8; %֡�������FFT��IFFT����
    Frame_len = PN_total_len + FFT_len; %֡��
    Super_Frame = 10; %��֡����
    Srrc_oversample = 1; %��������
    Symbol_rate = 7.56e6; %��������
    Sampling_rate = Symbol_rate * Srrc_oversample;%��������
    QAM = 0;    %  0: 64QAM ,2:256APSK
    BitPerSym = 6;
    sim_num=1000; %�����֡��
    iter_num = 3; %��������

    %%֡ͷ�ź�
    PN = PN_gen*1.975;

    %%���ջ�
    chan_len = PN_total_len;%�ŵ�����
    MAX_CHANNEL_LEN =PN_total_len;
    last_frame_tail = [0];
    stateSrrcReceive = [];
    h_prev1 = []; %ǰһ֡�ŵ�����
    h_prev2 = [];  %ǰ��֡�ŵ�����
    recover_data = zeros(1,sim_num*(Frame_len-PN_total_len));
    recover_data_pos = 1;
    start_pos = 1;
    h_off_thresh = 0.02; %����ǰ��֡�ŵ����Ƶ�ǰ֡ʱ���õ���ֵ

    debug_h_ave = 1;%�ж��Ƿ���ŵ�ƽ��
    h_average = zeros(1,2048); %�ŵ����Ƶ�ƽ�����
    h_ave_alpha = 0.95;
    h_start_ave_frame = 15;
    h_start_iter_frame = 105;
    h_average_thresh = 0.005;
    
    channel_estimate_spn = zeros(sim_num,MAX_CHANNEL_LEN);
    channel_estimate_dpn = zeros(sim_num,MAX_CHANNEL_LEN);
    channel_estimate_temp =  zeros(sim_num,MAX_CHANNEL_LEN);

    define_eq_total = 0;
    last_frame_data_conv = zeros(1,2048);
    %%��PN�ŵ�����
     for i=1:sim_num
          close all;
          Receive_data = Send_data_srrc_tx1_ch((i-1)*Frame_len+1:i*Frame_len);

          chan_in = Receive_data(1:PN_total_len+chan_len);
          chan_in(1:chan_len)= chan_in(1:chan_len)-last_frame_data_conv(PN_total_len+(1:chan_len));
          h_current = channel_estimate(chan_in, PN, 2048, 0.1,0);
          chan_len = min(chan_len_estimate(h_current),MAX_CHANNEL_LEN);
          h_current(chan_len+1:end)=0;
          h_pn_conv = channel_pn_conv(PN,h_current,chan_len);
          h_iter = h_current;
          for k = 1:iter_num
              if define_eq_total
                 eq_in_data = Send_data_srrc_tx1_ch((i-1)*Frame_len+PN_total_len+(1:Frame_len));
                 eq_data_freq = fft(eq_in_data);
                 h_freq = fft( h_iter,Frame_len);
                 eq_data_freq = (eq_data_freq./h_freq);
                 eq_data_freq(abs(h_freq)<h_off_thresh) =  0;
                 eq_data_time = ifft(eq_data_freq);
                 h_freq_fftlen =  fft( h_iter,2*PN_total_len);
                 fft_data_freq = fft(eq_data_time(1:PN_total_len),2*PN_total_len);
                 data_chan_conv = ifft(fft_data_freq.* h_freq_fftlen);
                 chan_in = Receive_data(1:PN_total_len+chan_len);
                 chan_in(1:chan_len)= chan_in(1:chan_len)-last_frame_data_conv(PN_total_len+(1:chan_len));
                 chan_in(PN_total_len+(1:chan_len))=chan_in(PN_total_len+(1:chan_len))-data_chan_conv(1:chan_len);
                 if i < h_start_iter_frame
                     if k == iter_num
                        h_iter = channel_estimate_A(chan_in, PN, 2048, 0);
                     else
                        h_iter = channel_estimate(chan_in, PN, 2048, 0.1, 0);
                     end
                 else
                     h_temp = channel_estimate_B(chan_in,PN, 2048,debug);
                     chan_len = min(chan_len_estimate(h_temp),MAX_CHANNEL_LEN);
                     h_temp(chan_len+1:end)=0;
                     channel_estimate_temp(i,:) = h_temp(1:PN_total_len);
                 end
                 
                 chan_len = min(chan_len_estimate(h_iter),MAX_CHANNEL_LEN);
                 h_iter(chan_len+1:end)=0;
                 h_pn_conv = channel_pn_conv(PN,h_iter,chan_len);
              else
                  eq_in_data = Receive_data(PN_total_len+1:end);
                  data_tail = Send_data_srrc_tx1_ch((i)*Frame_len+(1:chan_len))-h_pn_conv(1:chan_len);
                  eq_in_data(1:chan_len)=eq_in_data(1:chan_len)-h_pn_conv(PN_total_len+(1:chan_len))+data_tail;
                  eq_in_data_freq = fft(eq_in_data);
                  h_freq = fft( h_iter,FFT_len);
                  eq_data_freq = eq_in_data_freq./h_freq;
                  eq_data_freq(abs(h_freq)<h_off_thresh) = 0;
                  eq_data_time = ifft(eq_data_freq);
                 h_freq_fftlen =  fft( h_iter,2*PN_total_len);
                 fft_data_freq = fft(eq_data_time(1:PN_total_len),2*PN_total_len);
                 data_chan_conv = ifft(fft_data_freq.* h_freq_fftlen);
                 chan_in = Receive_data(1:PN_total_len+chan_len);
                 chan_in(1:chan_len)= chan_in(1:chan_len)-last_frame_data_conv(PN_total_len+(1:chan_len));
                 chan_in(PN_total_len+(1:chan_len))=chan_in(PN_total_len+(1:chan_len))-data_chan_conv(1:chan_len);
                if k == iter_num
                    h_iter = channel_estimate_A(chan_in, PN, 2048, 0);
                 else
                    h_iter = channel_estimate(chan_in, PN, 2048, 0.1, 0);
                 end
                 chan_len = min(chan_len_estimate(h_iter),MAX_CHANNEL_LEN);
                 h_iter(chan_len+1:end)=0;
                 h_pn_conv = channel_pn_conv(PN,h_iter,chan_len);
              end
          end
          channel_estimate_spn(i,:) = h_iter(1:PN_total_len);
          if debug||i==sim_num
              figure;
              plot(abs(h_iter));
              title('�������ƽ��');
              if debug
                pause
              end
          end
     end
end
 
 