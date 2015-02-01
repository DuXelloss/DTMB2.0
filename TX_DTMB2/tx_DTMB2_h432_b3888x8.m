%%DTMB2.0���ݷ��� ֡ͷ432��֡��3888*8��TPS 48,64QAM
clear all,close all,clc

debug = 0;
debug_multipath = 0;
debug_path_type = 101;
SNR_IN = 20;

%%��������
PN_len = 255;  % PN ����
PN_total_Len = 432; %֡ͷ����,ǰͬ��88����ͬ��89
PN_cyclic_Len = PN_total_Len - PN_len;%֡ͷ��ѭ����չ�ĳ���
PN_power = 3; %֡ͷ����dB
FFT_Len = 3888*8; %֡�������FFT��IFFT����
Frame_len = PN_total_Len + FFT_Len; %֡��
Super_Frame = 10; %��֡����
Srrc_oversample = 1; %��������
Symbol_rate = 7.56e6; %��������
Sampling_rate = Symbol_rate * Srrc_oversample;%��������
QAM = 0;    %  0: 64QAM ,2:256APSK
BitPerSym = 6;
sim_num=1000; %�����֡��

%%֡ͷ�ź�
PN = PN_gen*1.975;

%%֡��
data_bef_map=zeros(1,FFT_Len*BitPerSym);
data_aft_map_tx1 = zeros(1,Frame_len*sim_num);

%%channel
max_delay = 10;
doppler_freq = 0;
isFading = 0;
channelFilter = 1;
if debug_multipath
    channelFilter = get_multipath_channel(debug_path_type,isFading,max_delay,doppler_freq,Sampling_rate,Symbol_rate);
end

%%data
start_pos = 1;
data_transfer = zeros(1,sim_num*FFT_Len);
data_start_pos = 1;
for i=1:sim_num
    data_x = randi([0 1],1,FFT_Len*BitPerSym);
    modtemp1=map64q(data_x); %%����ӳ��
    modtemp= modtemp1*3888*20;
    temp_t1=ifft(modtemp, FFT_Len);
    data_transfer(data_start_pos:data_start_pos+FFT_Len-1)=modtemp;
    data_start_pos = data_start_pos + FFT_Len;
    
    frm_len = Frame_len;
    data_aft_map_tx1(start_pos:start_pos+frm_len-1)=[PN temp_t1];
    start_pos = start_pos+frm_len;
end

Send_data_srrc_tx1 = data_aft_map_tx1;
Send_data_srrc_tx1_ch1 = filter(channelFilter,1,Send_data_srrc_tx1);%���ŵ�
Send_data_srrc_tx1_ch = awgn(Send_data_srrc_tx1_ch1,SNR_IN,'measured');
SNR_Old = estimate_SNR(Send_data_srrc_tx1_ch,Send_data_srrc_tx1_ch1)

%%���ջ�
chan_len = 260;%�ŵ�����
MAX_CHANNEL_LEN = PN_total_Len;
last_frame_tail = [0];
stateSrrcReceive = [];
h_prev1 = []; %ǰһ֡�ŵ�����
h_prev2 = [];  %ǰ��֡�ŵ�����
recover_data = zeros(1,sim_num*(Frame_len-PN_total_Len));
recover_data_pos = 1;
start_pos = 1;
h_off_thresh = 0.2; %����ǰ��֡�ŵ����Ƶ�ǰ֡ʱ���õ���ֵ
 for i=1:sim_num
      Receive_data = Send_data_srrc_tx1_ch((i-1)*Frame_len+1:i*Frame_len);
      
      if(i < 3)  %ǰ��֡�����ŵ����ƣ�������
          chan_in = Receive_data(1:PN_total_Len+chan_len);
          h_current = channel_estimate(chan_in, PN);
          h_pn_conv = channel_pn_conv(PN,h_current,chan_len);
          %����״̬
          h_prev2 = h_prev1;
          h_prev1 = h_current;
	      h_pn_conv_prv = h_pn_conv;
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
          figure;hold on;
          plot(abs(sc_h1),'r');
          plot(abs(sc_h2),'b');

          figure;hold on;
          plot(abs(h_pn_conv),'r');
           plot(abs(h_pn_conv_prv),'b');
          title('PN���ŵ�����Ľ��');
          hold off;
         % pause;
          %%���
          figure;
          fft_data = fft(last_frame_data(PN_total_Len+1:Frame_len));
          plot(fft_data,'.');
          title('��һ֡����');
          %pause;
      end
      
      last_frame_data_tail_head =  last_frame_data(PN_total_Len+1:end);
      last_frame_pn_tail = h_pn_conv_prv(PN_total_Len+(1:chan_len));
      last_frame_data_tail = Send_data_srrc_tx1_ch((i-1)*Frame_len+(1:chan_len))- h_pn_conv(1:chan_len);
      last_frame_data_tail_head(1:chan_len) = last_frame_data_tail_head(1:chan_len)-last_frame_pn_tail+ last_frame_data_tail;
      last_frame_ofdm_freq = fft(last_frame_data_tail_head);
      last_frame_h_freq = fft(sc_ha,FFT_Len);
      
      if debug || i== sim_num
          figure;
          fft_data_test = fft(last_frame_data_tail_head);
          plot(fft_data_test,'.');
          title('ȥ��PN���ź�Ľ��');
          
          %pause;
          figure;
          plot(abs(last_frame_h_freq));
          title('�ŵ����ƽ��');
      end
      
      last_frame_ofdm_eq =  last_frame_ofdm_freq./last_frame_h_freq;
      last_frame_ofdm_eq_data = ifft(last_frame_ofdm_eq);
      last_frame_ofdm_eq_data =last_frame_ofdm_eq_data(1:FFT_Len);
      fft_data = fft(last_frame_ofdm_eq_data);
      recover_data((i-2)*FFT_Len+1:(i-1)*FFT_Len)=  fft_data;
      
      if debug || i== sim_num
          figure;
          plot(fft_data,'.b');
          title('����������');
          if debug
             pause;
          end
      end
      iter_num = 2;
      h_iter = sc_h1;
      last_frame_ofdm_eq_freq = fft(last_frame_ofdm_eq_data, 32*1024);
      last_frame_h_32k = fft(sc_ha,32*1024);
      last_frame_ofdm_h =  last_frame_ofdm_eq_freq.* last_frame_h_32k;
      last_frame_ofdm_h_conv = ifft(last_frame_ofdm_h);
      last_frame_data_tail = last_frame_ofdm_h_conv(FFT_Len+1:FFT_Len+chan_len);
      current_frame_pn = Receive_data(1:PN_total_Len);
      current_frame_pn(1:chan_len)=current_frame_pn(1:chan_len)-last_frame_data_tail;
      for k = 1 : iter_num
          h_pn_conv = channel_pn_conv(PN,h_iter,chan_len);
          pn_recover = [current_frame_pn h_pn_conv(PN_total_Len+(1:chan_len))];
          h_iter = channel_estimate(pn_recover,PN);
%           pn_receive_freq = fft(pn_recover, 2048);
%           pn_freq = fft(PN, 2048);
%           pn_freq_eq = pn_receive_freq./pn_freq;
%           h_time = ifft(pn_freq_eq);
      end
      chan_len = min(chan_len_estimate(h_iter),MAX_CHANNEL_LEN);
      h_prev2 = h_prev1;
      h_prev1 = h_iter;
	  h_pn_conv_prv = channel_pn_conv(PN,h_iter,chan_len);
      
 end
 
 SNR = estimate_SNR(recover_data(9:FFT_Len+1:end),data_transfer(9:FFT_Len+1:end))