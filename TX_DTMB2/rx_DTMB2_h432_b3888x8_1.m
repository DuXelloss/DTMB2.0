%%channel estimation    
%%DTMB2.0���ݷ��� ֡ͷ432��֡��3888*8��TPS 48,64QAM
%%����2
clear all,close all,clc
debug = 0;
SNR = [20];

spn_mse = zeros(1,length(SNR));
dpn_mse = zeros(1,length(SNR));
mse_pos = 1;
for SNR_IN = SNR %�������������
debug_multipath = 1;%�����Ƿ��Ƕྶ
debug_path_type = 1;%����ྶ����
if debug_multipath
    matfilename = strcat('DTMB_data_multipath_new',num2str(debug_path_type),'SNR',num2str(SNR_IN),'.mat');
    load(matfilename);
else
    load strcat('DTMB_data_awgn_SNR',num2str(SNR_IN),'.mat');
end

debug_frame_32k_eq = 0;%��������֡���ⳤ�ȣ�1Ϊ32K�� 0ΪFFT_Len

%%��������
PN_len = 255;  % PN ����
PN_total_Len = 432; %֡ͷ����,ǰͬ��88����ͬ��89
DPN_total_len = 1024;
DPN_len = 512;
load pn256_pn512.mat
PN_cyclic_Len = PN_total_Len - PN_len;%֡ͷ��ѭ����չ�ĳ���
PN_power = 3; %֡ͷ����dB
FFT_len = 3888*8; %֡�������FFT��IFFT����
Frame_len = PN_total_Len + FFT_len; %֡��
Super_Frame = 10; %��֡����
Srrc_oversample = 1; %��������
Symbol_rate = 7.56e6; %��������
Sampling_rate = Symbol_rate * Srrc_oversample;%��������
QAM = 0;    %  0: 64QAM ,2:256APSK
BitPerSym = 6;
sim_num=1000; %�����֡��

%%֡ͷ�ź�
PN = PN_gen*1.975;

%%���ջ�
chan_len = 260;%�ŵ�����
MAX_CHANNEL_LEN =PN_total_Len;
last_frame_tail = [0];
stateSrrcReceive = [];
h_prev1 = []; %ǰһ֡�ŵ�����
h_prev2 = [];  %ǰ��֡�ŵ�����
recover_data = zeros(1,sim_num*(Frame_len-PN_total_Len));
recover_data_pos = 1;
start_pos = 1;
h_off_thresh = 0.2; %����ǰ��֡�ŵ����Ƶ�ǰ֡ʱ���õ���ֵ
channel_estimate_result = zeros(sim_num,PN_total_Len);
channel_estimate_2 = zeros(sim_num,MAX_CHANNEL_LEN);
 for i=1:sim_num
      Receive_data = Send_data_srrc_tx1_ch((i-1)*Frame_len+1:i*Frame_len);
      
       if i < 30
      channel_estimate_thresh = 0.1;
      else
      channel_estimate_thresh = 0.05;  
       end
      
      if(i < 3)  %ǰ��֡�����ŵ����ƣ�������
          chan_in = Receive_data(1:PN_total_Len+chan_len);
          h_current = channel_estimate(chan_in, PN, 2048,channel_estimate_thresh);
          h_pn_conv = channel_pn_conv(PN,h_current,chan_len);
          %����״̬
          h_prev2 = h_prev1;
          h_prev1 = h_current;
	      h_pn_conv_prv = h_pn_conv;
          channel_estimate_result(i,:) = h_current(1:PN_total_Len);
          continue;
      end
      
%       close all;
%       figure;
%       plot(abs(Receive_data));
%       title('��ǰ֡���ݷ���');
     
      %%��һ֡���ݹ���
      [sc_h1 sc_h2 sc_ha] = h_estimate_A(h_prev2, h_prev1, i, h_off_thresh);
      h_pn_conv = channel_pn_conv(PN,sc_h1,chan_len);
      last_frame_data =  Send_data_srrc_tx1_ch((i-2)*Frame_len+1:(i-1)*Frame_len);
     
      if debug || i== sim_num
          close all;
%           figure;
%           subplot(2,1,1);
%           plot(abs(sc_h1(1:PN_total_Len)),'r');
%           title('��ǰ֡�ŵ�����');
%           subplot(2,1,2);
%           plot(abs(sc_h2(1:PN_total_Len)),'b');
%            title('��ǰ֡��һ֡�ŵ�����');
%           figure;hold on;
%           plot(abs(h_pn_conv),'r');
%            plot(abs(h_pn_conv_prv),'b');
%           title('PN���ŵ�����Ľ��');
%           hold off;
         % pause;
          %%���
%           figure;
%           fft_data = fft(last_frame_data(PN_total_Len+1:Frame_len));
%           plot(fft_data,'.');
%           title('��һ֡����');
          %pause;
      end
      
      last_frame_data_tail = Send_data_srrc_tx1_ch((i-1)*Frame_len+(1:chan_len))- h_pn_conv(1:chan_len);
      last_frame_pn_tail = h_pn_conv_prv(PN_total_Len+(1:chan_len));
      
      if debug_frame_32k_eq
           last_frame_data_tail_head = [ last_frame_data(PN_total_Len+1:end),last_frame_data_tail ];
           last_frame_data_tail_head(1:chan_len) = last_frame_data_tail_head(1:chan_len)-last_frame_pn_tail;
           last_frame_ofdm_freq = fft(last_frame_data_tail_head, 32*1024);
           last_frame_h_freq = fft(sc_ha,32*1024);
      else
           last_frame_data_tail_head =  last_frame_data(PN_total_Len+1:end);
           last_frame_data_tail_head(1:chan_len) = last_frame_data_tail_head(1:chan_len)-last_frame_pn_tail+ last_frame_data_tail;
           last_frame_ofdm_freq = fft(last_frame_data_tail_head);
           last_frame_h_freq = fft(sc_ha,FFT_len);
      end
      
      if debug || i== sim_num
%           figure;
%           fft_data_test = fft(last_frame_data_tail_head);
%           plot(fft_data_test,'.');
%           title('ȥ��PN���ź�Ľ��');
%           
%           %pause;
%           figure;
%           plot(abs(last_frame_h_freq));
%           title('�ŵ����ƽ��');
      end
      
      
     last_frame_ofdm_eq =  last_frame_ofdm_freq./last_frame_h_freq;
     last_frame_ofdm_eq_data = ifft(last_frame_ofdm_eq);
     last_frame_ofdm_eq_data =last_frame_ofdm_eq_data(1:FFT_len);
     fft_data = fft(last_frame_ofdm_eq_data);
     recover_data((i-2)*FFT_len+1:(i-1)*FFT_len)=  fft_data;
      
      if debug || i== sim_num
          figure;
          plot(fft_data,'.b');
          title('����������');
      end
      iter_num = 2;
      h_iter = sc_h1;
      last_frame_ofdm_eq_freq = fft(last_frame_ofdm_eq_data, 32*1024);
      last_frame_h_32k = fft(sc_ha,32*1024);
      last_frame_ofdm_h =  last_frame_ofdm_eq_freq.* last_frame_h_32k;
      last_frame_ofdm_h_conv = ifft(last_frame_ofdm_h);
      last_frame_data_tail = last_frame_ofdm_h_conv(FFT_len+1:FFT_len+chan_len);
      current_frame_pn = Receive_data(1:PN_total_Len);
      current_frame_pn(1:chan_len)=current_frame_pn(1:chan_len)-last_frame_data_tail;
      for k = 1 : iter_num
          h_pn_conv = channel_pn_conv(PN,h_iter,chan_len);
          pn_recover = [current_frame_pn h_pn_conv(PN_total_Len+(1:chan_len))];
          h_iter = channel_estimate(pn_recover,PN, 2048,channel_estimate_thresh);
%           pn_receive_freq = fft(pn_recover, 2048);
%           pn_freq = fft(PN, 2048);
%           pn_freq_eq = pn_receive_freq./pn_freq;
%           h_time = ifft(pn_freq_eq);
      end
      
      if debug || i== sim_num
       figure;
       subplot(1,2,1);
       plot(abs(sc_h1(1:PN_total_Len)),'r');
       title('��ʼ�ŵ�����');
       subplot(1,2,2);
       plot(abs( h_iter(1:PN_total_Len)),'b');
       title('�����ŵ�����');
       if debug
             pause;
        end
      end
      
      chan_len = min(chan_len_estimate(h_iter),MAX_CHANNEL_LEN);
      h_prev2 = h_prev1;
      h_prev1 = h_iter;
	  h_pn_conv_prv = channel_pn_conv(PN,h_iter,chan_len);
      channel_estimate_result(i,:) = h_iter(1:PN_total_Len);
 end
 
 if debug_multipath
     max_delay = 10;
    doppler_freq = 0;
    isFading = 0;
    channelFilter = multipath_new(debug_path_type,1/7.56,1,0);
    channel_real = zeros(1,PN_total_Len);
    channel_real(1:length(channelFilter)) = channelFilter;
    figure;
    plot(channel_real);
    title('��ʵ�ྶ�ŵ�');
 else
     channel_real = zeros(1,PN_total_Len);
     channel_real(1) = 1;
 end
 
  %% dual pn estimate 
 frame_test = DPN_total_len + FFT_len;
 for i=1:sim_num-1
      Receive_data = Send_data_srrc_tx1_ch2((i-1)*frame_test+(1:frame_test));
      pn_test = Receive_data(DPN_len+(1:DPN_len));
      coeff = 6.4779e+04;
      pn_test = pn_test ./ coeff;
      pn512_fft = fft(pn_test);
      dpn_h_freq =  pn512_fft./ pn512;
      dpn_h_time = ifft(dpn_h_freq);
      chan_len_test = chan_len_estimate(dpn_h_time);
      channel_estimate_2(i,1:chan_len_test)=dpn_h_time(1:chan_len_test);
      if debug || (i== sim_num-1 && k == iter_num)
        figure;
        plot(abs(dpn_h_time));
        title('˫PN�ŵ����ƽ��');
        if debug
            pause;
        end
      end 
 end
 
  kk = 1;
 num = sim_num-14;
 for i = 9+(1:num)
     spn_channel_off = channel_estimate_result(i,:) - channel_real;
     dpn_channel_off = channel_estimate_2(i,:) - channel_real;
     spn_channel_mse(kk) = norm(spn_channel_off)/norm(channel_real);
     dpn_channel_mse(kk) = norm(dpn_channel_off)/norm(channel_real);
     kk = kk + 1;
 end
 spn_chan_off_mse = mean(spn_channel_mse);
 dpn_chan_off_mse = mean(dpn_channel_mse);
 spn_mse(mse_pos) = spn_chan_off_mse;
 dpn_mse(mse_pos) = dpn_chan_off_mse;
 mse_pos = mse_pos + 1;
end

figure;
subplot(1,2,1)
semilogy(SNR,spn_mse,'r');
title('��PN����MSE');
subplot(1,2,2)
semilogy(SNR,dpn_mse,'b');
title('˫PN����MSE');