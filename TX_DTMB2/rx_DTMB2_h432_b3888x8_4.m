%%channel estimation 
%%���� 
%%���ݸ�������
%%DTMB2.0���ݷ��� ֡ͷ432��֡��3888*8��TPS 48,64QAM
%%����2
clear all,close all,clc
debug = 0;
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
    chan_len = 260;%�ŵ�����
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

    define_eq_total = 1;
    %%��PN�ŵ�����
     for i=1:1
          close all;
          Receive_data = Send_data_srrc_tx1_ch((i-1)*Frame_len+1:i*Frame_len);

          chan_in = Receive_data(1:2*PN_total_len);
          h_current = channel_estimate(chan_in, PN, 2048, 0.1,debug);
          for k = 1:iter_num
              if define_eq_total
              else
              end
          end
     end
end
 figure;
 plot(abs(h_current));
 