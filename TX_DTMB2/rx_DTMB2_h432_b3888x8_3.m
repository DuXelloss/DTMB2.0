%%channel estimation 
%%���� 1.Channel Estimation for the Chinese DTTB
%%��βƴ��
%%DTMB2.0���ݷ��� ֡ͷ432��֡��3888*8��TPS 48,64QAM
%%����2
clear all,close all,clc
debug = 0;
debug_tps = 1;
SNR = [25];

spn_mean_mse = zeros(1,length(SNR));
dpn_mean_mse = zeros(1,length(SNR));
spn_pnrm_SNR = zeros(1,length(SNR));
dpn_pnrm_SNR = zeros(1,length(SNR));
spn_pn_chan_conv_freq_SNR = zeros(1,length(SNR));
dpn_pn_chan_conv_freq_SNR = zeros(1,length(SNR));

mse_pos = 1;
for SNR_IN = SNR %�������������
    
%%��������
debug_multipath = 1;%�����Ƿ��Ƕྶ
debug_path_type = 8;%����ྶ����
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
temp = ifft(pn512);
DPN = temp*sqrt(var(PN)/var(temp));

%%�ŵ�
channelFilter = multipath_new(debug_path_type,1/7.56,1,0);
channel_real = zeros(1,PN_total_len);
channel_real(1:length(channelFilter)) = channelFilter;
    
%%���ջ�
chan_len = 100;%�ŵ�����
MAX_CHANNEL_LEN =PN_total_len;
last_frame_tail = [0];
stateSrrcReceive = [];
h_prev1 = []; %ǰһ֡�ŵ�����
h_prev2 = [];  %ǰ��֡�ŵ�����
recover_data = zeros(1,sim_num*(Frame_len-PN_total_len));
recover_data_dpn = zeros(1,sim_num*(Frame_len-PN_total_len));
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

%��PNȥ��PN��β������ݻָ����
spn_rcov_channel_data_time = zeros(1,FFT_len*(sim_num-1));
%��PN�ŵ����ƽ������ʵ�������ݵľ�����
spn_ch_data_conv_time = zeros(1,FFT_len*(sim_num-1));
spn_ch_data_conv_freq = zeros(1,FFT_len*(sim_num-1));
h_iter = zeros(1,1024);
%��PN�ŵ�����
 for i=1:sim_num-1
      close all;
      figure;
      plot(abs(channel_real));
      title('��ʵ�ྶ�ŵ�');
      Receive_data = Send_data_srrc_tx1_ch((i-1)*Frame_len+1:i*Frame_len);
      
      if(i < 3)  %ǰ��֡�����ŵ����ƣ�������
          chan_in = Receive_data(1:PN_total_len+chan_len);
          h_current = channel_estimate(chan_in, PN, 2048, 0.1,debug);
          h_current(chan_len+1:end)=0;
          h_pn_conv = channel_pn_conv(PN,h_current,chan_len);
          %����״̬
          h_prev2 = h_prev1;
          h_prev1 = h_current;
	      h_pn_conv_prv = h_pn_conv;
          channel_estimate_spn(i,:) = h_current(1:PN_total_len);
          continue;
      end
       
      %%��һ֡���ݹ���
      [sc_h1 sc_h2 sc_ha] = h_estimate_A(h_prev2, h_prev1, i, h_off_thresh);
      h_pn_conv = channel_pn_conv(PN,sc_h1,chan_len);
      last_frame_data =  Send_data_srrc_tx1_ch((i-2)*Frame_len+1:(i-1)*Frame_len);
      last_frame_data_tail = Send_data_srrc_tx1_ch((i-1)*Frame_len+(1:chan_len))- h_pn_conv(1:chan_len);
      last_frame_pn_tail = h_pn_conv_prv(PN_total_len+(1:chan_len));
      
      last_frame_data_tail_head =  last_frame_data(PN_total_len+1:end);
      last_frame_data_tail_head(1:chan_len) = last_frame_data_tail_head(1:chan_len)-last_frame_pn_tail+ last_frame_data_tail;
      spn_rcov_channel_data_time((i-2)*FFT_len+(1:FFT_len))= last_frame_data_tail_head;
      
      last_frame_h_freq = fft(sc_ha,FFT_len);
      spn_ch_data_conv_freq((i-2)*FFT_len+(1:FFT_len))=last_frame_h_freq.*data_transfer((i-2)*FFT_len+(1:FFT_len));
      
      if debug_frame_32k_eq
           last_frame_data_tail_head = [ last_frame_data(PN_total_len+1:end),last_frame_data_tail ];
           last_frame_data_tail_head(1:chan_len) = last_frame_data_tail_head(1:chan_len)-last_frame_pn_tail;
           last_frame_ofdm_freq = fft(last_frame_data_tail_head, 32*1024);
           last_frame_h_freq = fft(sc_ha,32*1024);
      else
           last_frame_data_tail_head =  last_frame_data(PN_total_len+1:end);
           last_frame_data_tail_head(1:chan_len) = last_frame_data_tail_head(1:chan_len)-last_frame_pn_tail+ last_frame_data_tail;
           last_frame_ofdm_freq = fft(last_frame_data_tail_head);
           last_frame_h_freq = fft(sc_ha,FFT_len);
      end
       
     last_frame_ofdm_eq =  last_frame_ofdm_freq./last_frame_h_freq;
     max_h = max(abs(last_frame_h_freq));
     last_frame_ofdm_eq(abs(last_frame_h_freq)<max_h*h_average_thresh)=0;
     last_frame_ofdm_eq_data = ifft(last_frame_ofdm_eq);
     last_frame_ofdm_eq_data =last_frame_ofdm_eq_data(1:FFT_len);
     
     fft_data = fft(last_frame_ofdm_eq_data);
     if debug_tps 
         channel_temp = channel_estimate_spn(i-1,:);
         channel_freq = fft(channel_temp, FFT_len);
         channel_freq(tps_position)= fft_data(tps_position)./tps_symbol;
         fft_data(tps_position)=tps_symbol;
     end
     recover_data((i-2)*FFT_len+1:(i-1)*FFT_len)=  fft_data;
     last_frame_ofdm_eq_data = ifft(fft_data);
      
      if debug || i== sim_num-1
          figure;
          plot(fft_data,'.b');
          title('����������');
      end
      h_iter = sc_h1;
      last_frame_ofdm_eq_freq = fft(last_frame_ofdm_eq_data, 32*1024);
      last_frame_h_32k = fft(sc_ha,32*1024);
      last_frame_ofdm_h =  last_frame_ofdm_eq_freq.* last_frame_h_32k;
      last_frame_ofdm_h_conv = ifft(last_frame_ofdm_h);
      last_frame_data_tail = last_frame_ofdm_h_conv(FFT_len+1:FFT_len+chan_len);
      current_frame_pn = Receive_data(1:PN_total_len);
      current_frame_pn(1:chan_len)=current_frame_pn(1:chan_len)-last_frame_data_tail;
      for k = 1 : iter_num
          if debug_h_ave && i > h_start_ave_frame 
                if i < h_start_iter_frame
                    h_pn_conv = channel_pn_conv(PN,h_iter,chan_len);
                    pn_recover = [current_frame_pn h_pn_conv(PN_total_len+(1:chan_len))];
                    h_iter = channel_estimate_A(pn_recover,PN, 2048,0);
                    if k == iter_num
                        h_pn_conv = channel_pn_conv(PN,h_iter,chan_len);
                        pn_recover = [current_frame_pn h_pn_conv(PN_total_len+(1:chan_len))];
                        h_temp = channel_estimate_B(pn_recover,PN, 2048,0);
                        chan_len = min(chan_len_estimate(h_temp),MAX_CHANNEL_LEN);
                        h_temp(chan_len+1:end)=0;
                        channel_estimate_temp(i,:) = h_temp(1:PN_total_len);
                    end
                elseif i >= h_start_iter_frame
                    h_pn_conv = channel_pn_conv(PN,h_iter,chan_len);
                    pn_recover = [current_frame_pn h_pn_conv(PN_total_len+(1:chan_len))];
                    h_temp = channel_estimate_B(pn_recover,PN, 2048,0);
                    chan_len = min(chan_len_estimate(h_temp),MAX_CHANNEL_LEN);
                    h_temp(chan_len+1:end)=0;
                    channel_estimate_temp(i,:) = h_temp(1:PN_total_len);
                    h_iter(1:PN_total_len) = mean(channel_estimate_temp(h_start_ave_frame+1:i,:));
                else
                   display('other');
                end
          else
              if k==1
                channel_estimate_thresh = 0.06;
              elseif k==2
                channel_estimate_thresh = 0.05;
              else
                channel_estimate_thresh = 0.05-0.01*(k-2);
                if 0.05-0.01*(k-2) < 0.01
                    channel_estimate_thresh = 0.01;
                end
              end

              h_pn_conv = channel_pn_conv(PN,h_iter,chan_len);
              pn_recover = [current_frame_pn h_pn_conv(PN_total_len+(1:chan_len))];
              if k==1
                  h_iter = channel_estimate(pn_recover,PN, 2048,channel_estimate_thresh,debug);
              else
                  h_iter = channel_estimate_A(pn_recover,PN, 2048,debug);
              end
              chan_len = min(chan_len_estimate(h_iter)+10,MAX_CHANNEL_LEN);
              h_iter(chan_len+1:end)=0;
          end
      end     
      h_iter_old = sc_h1;
      
      if debug
      figure;
      subplot(1,2,1);
      plot(abs(h_iter_old(1:PN_total_len)),'r');
      title('��ʼ�ŵ�����');
       subplot(1,2,2);
       plot(abs(h_iter(1:PN_total_len)),'b');
       title('�����ŵ�����');
       if debug
             pause;
        end
      end
      chan_len = min(chan_len_estimate(h_iter),MAX_CHANNEL_LEN);
      h_iter(chan_len+1:end)=0;
      h_prev2 = h_prev1;
      h_prev1 = h_iter;
	  h_pn_conv_prv = channel_pn_conv(PN,h_iter,chan_len);
     channel_estimate_spn(i,:) = h_iter(1:PN_total_len);
 end
 
 %%��ʵ�ྶ�ŵ��뵥PN���ƽ���Ƚ�
 if debug_multipath
    figure;
    subplot(1,2,1);
    plot(abs(channel_real));
    title('��ʵ�ྶ�ŵ�');
    subplot(1,2,2);
    plot(abs( h_iter(1:PN_total_len)),'b');
    title('�����ŵ�����');   
 else
     channel_real = zeros(1,PN_total_len);
     channel_real(1) = 1;
 end
 
 %��ʵ��������ʵ�ŵ��ľ�����
 rcov_channel_real_data_time = zeros(1,FFT_len*(sim_num-1));
 rcov_channel_real_data_freq = zeros(1,FFT_len*(sim_num-1));
 
 %˫PNȥ��PN��β������ݻָ����
 dpn_rcov_channel_data_time = zeros(1,FFT_len*(sim_num-1));
 %˫PN�ŵ����ƽ������ʵ�������ݵľ�����
dpn_ch_data_conv_time = zeros(1,FFT_len*(sim_num-1));
dpn_ch_data_conv_freq = zeros(1,FFT_len*(sim_num-1));

 channel_real_freq = fft(channel_real,FFT_len);
 
  %% ˫PN�ŵ�����
 frame_test = DPN_total_len + FFT_len;
 for i=1:sim_num-1
      Receive_data = Send_data_srrc_tx1_ch2((i-1)*frame_test+(1:frame_test));
      pn_test = Receive_data(DPN_len+(1:DPN_len));
      coeff = 6.4779e+04;
      pn_test = pn_test ./ coeff;
      pn512_fft = fft(pn_test);
      dpn_h_freq =  pn512_fft./ pn512;
      dpn_h_time = ifft(dpn_h_freq);
      chan_len_dpn = min(chan_len_estimate(dpn_h_time)+20,MAX_CHANNEL_LEN);
      dpn_h_time(chan_len_dpn+1:end)=0;
      channel_estimate_dpn(i,1:PN_total_len)=dpn_h_time(1:PN_total_len);
%       close all;
%       figure;
%       plot(abs(channel_real));
%       title('��ʵ�ྶ�ŵ�');
%       figure;
%       plot(abs(dpn_h_time));
      
      temp_PN = DPN;
      temp_PN_len = DPN_len;
      temp_total_len = DPN_total_len;
       
      frame_test =temp_total_len + FFT_len;
      Receive_data = Send_data_srrc_tx1_ch2((i-1)*frame_test+(1:frame_test));
      
      data_real =  data_transfer((i-1)*FFT_len+(1:FFT_len)).*channel_real_freq;
      rcov_channel_real_data_freq((i-1)*FFT_len+(1:FFT_len))= data_real;
      rcov_channel_real_data_time((i-1)*FFT_len+(1:FFT_len))= ifft(data_real);
       
      %%���ݻָ�
      dpn_chan_mean = mean(channel_estimate_dpn(1:i,:));
      chan_len_dpn = min(chan_len_estimate(dpn_chan_mean),MAX_CHANNEL_LEN)+10;
      dpn_chan_mean(chan_len_dpn+1:end)=0;
      dpn_h_freq_frame = fft(dpn_chan_mean,FFT_len);
      
      pn_conv = channel_pn_conv( temp_PN, dpn_chan_mean,chan_len_dpn);
      frame_tail =  Send_data_srrc_tx1_ch2(i*frame_test+(1:chan_len_dpn))-pn_conv(1:chan_len_dpn);
      frame_data =  Receive_data(temp_total_len+1:end);
      frame_data(1:chan_len_dpn) = frame_data(1:chan_len_dpn)-pn_conv(temp_PN_len+(1:chan_len_dpn))+frame_tail;
   
      dpn_rcov_channel_data_time((i-1)*FFT_len+(1:FFT_len))=  frame_data;
      dpn_ch_data_conv_freq((i-1)*FFT_len+(1:FFT_len))=data_transfer((i-1)*FFT_len+(1:FFT_len)).*dpn_h_freq_frame;
      
      fft_data_dpn = fft(frame_data);
      fft_data_dpn = fft_data_dpn./dpn_h_freq_frame;
      recover_data_dpn((i-1)*FFT_len+1:(i)*FFT_len)=  fft_data_dpn;
 end
 
  figure;
  plot(fft_data_dpn,'.k');
  title('˫PN���ݾ�����');
     
 %%�������
 num = sim_num-9;
 mean_pos = h_start_iter_frame+1:num;
 dpn_channel_mean = mean(channel_estimate_dpn(mean_pos,:));
 chan_len = min(chan_len_estimate(dpn_channel_mean)+10,MAX_CHANNEL_LEN);
 dpn_channel_mean(chan_len+1:end)=0;
 dpn_mean_off = dpn_channel_mean -  channel_real;
 dpn_mean_mse(mse_pos) = norm(dpn_mean_off)/norm(channel_real);
 
 spn_channel_mean = mean(channel_estimate_spn(mean_pos,:));
 spn_mean_off = spn_channel_mean -  channel_real;
 spn_mean_mse(mse_pos) = norm(spn_mean_off)/norm(channel_real);

 temp_mean = mean(channel_estimate_temp(mean_pos,:));
 chan_len = min(chan_len_estimate(temp_mean),MAX_CHANNEL_LEN);
 temp_mean(chan_len+1:end)=0;
 temp_off = temp_mean -  channel_real;
 temp_mse(mse_pos) =  norm(temp_off)/norm(channel_real);
 
 if debug || i== sim_num-1 
        figure;
        subplot(1,2,1);
        plot(abs(channel_real));
        title('��ʵ�ྶ�ŵ�');
        subplot(1,2,2);
        plot(abs(dpn_channel_mean));
        title('˫PN�ŵ�ƽ�����ƽ��');
        figure;
        subplot(1,2,1);
        plot(abs(channel_real));
        title('��ʵ�ྶ�ŵ�');
        subplot(1,2,2);
        plot(abs(spn_channel_mean));
        title('��PN�ŵ�ƽ�����ƽ��');
        figure;
        subplot(1,2,1);
        plot(abs(channel_real));
        title('��ʵ�ྶ�ŵ�');
        subplot(1,2,2);
        plot(abs(temp_mean));
        title('tempƽ�����ƽ��');
        if debug
            pause;
        end
 end 
 
 start_pos = FFT_len* h_start_iter_frame+1;
 end_pos = FFT_len*(sim_num-9);
 dpn_pnrm_SNR(mse_pos) = estimate_SNR(dpn_rcov_channel_data_time(start_pos:end_pos),rcov_channel_real_data_time(start_pos:end_pos))
 spn_pnrm_SNR(mse_pos) = estimate_SNR(spn_rcov_channel_data_time(start_pos:end_pos),rcov_channel_real_data_time(start_pos:end_pos))
 spn_pn_chan_conv_freq_SNR(mse_pos) = estimate_SNR(spn_ch_data_conv_freq(start_pos:end_pos),rcov_channel_real_data_freq(start_pos:end_pos))
 dpn_pn_chan_conv_freq_SNR(mse_pos) = estimate_SNR(dpn_ch_data_conv_freq(start_pos:end_pos),rcov_channel_real_data_freq(start_pos:end_pos))
 mse_pos = mse_pos + 1;
end

figure;
subplot(1,2,1)
semilogy(SNR,temp_mse,'r*-');
title('��PN����MSE');
subplot(1,2,2)
semilogy(SNR,dpn_mean_mse,'k*-');
title('˫PN����MSE');

figure;hold on;
plot(SNR,spn_pnrm_SNR,'r*-');
plot(SNR,dpn_pnrm_SNR,'k*-');
legend('��PN','˫PN');
title('����ѭ���ع���������');
hold off;

figure;hold on;
plot(SNR,spn_pn_chan_conv_freq_SNR,'r*-');
plot(SNR,dpn_pn_chan_conv_freq_SNR,'k*-');
legend('��PN','˫PN');
title('�ŵ��������������');