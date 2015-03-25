%%iterative channel estimation   
%%DTMB2.0���ݷ��� ֡ͷ432��֡��3888*8��TPS 48,64QAM
clear all,close all,clc

debug = 0;
debug_multipath = 1;%�����Ƿ��Ƕྶ
debug_path_type = 16;%����ྶ����
SNR = [20:5:30];
for SNR_IN = SNR  %�������������

%%��������
PN_len = 255;  % PN ����
PN_total_len = 432; %֡ͷ����,ǰͬ��88����ͬ��89
DPN_total_len = 1024;
PN_cyclic_Len = PN_total_len - PN_len;%֡ͷ��ѭ����չ�ĳ���
PN_power = 3; %֡ͷ����dB
FFT_len = 3888*8; %֡�������FFT��IFFT����
Frame_len = PN_total_len + FFT_len; %֡��
Super_Frame = 100; %��֡����
Srrc_oversample = 1; %��������
Symbol_rate = 7.56e6; %��������
Sampling_rate = Symbol_rate * Srrc_oversample;%��������
QAM = 0;    %  0: 64QAM ,2:256APSK
BitPerSym = 6;
sim_num=1000; %�����֡��

load pn256_pn512.mat
%%֡ͷ�ź�
PN = PN_gen_old*1.975;
temp = ifft(pn512);
DPN = temp*sqrt(var(PN)/var(temp));

%%֡��
data_bef_map=zeros(1,FFT_len*BitPerSym);
data_aft_map_tx1 = zeros(1,Frame_len*sim_num);

%%channel
max_delay = 10;
doppler_freq = 0;
isFading = 0;
channelFilter = 1;
if debug_multipath
    channelFilter = multipath_new(debug_path_type,1/7.56,1,0);
end

%%TPS
tps_len = 48*8;
tps_symbol = zeros(1,tps_len);
tps_position =[];
d = 0; %��ɢ��ƵΪ2d+1
discret_num = ceil(tps_len/(2*d+1));
tps_block_len = floor(FFT_len/discret_num);
dimY = 3;
dimX_len = tps_block_len/dimY;
for kk = 1:discret_num
    temp = (kk-1)*(tps_block_len)+(1:2*d+1);
    tps_position = [tps_position temp];
end
 tps_position = tps_position(1:tps_len);
 tps_data = randi([0 1],1,tps_len*BitPerSym);
 modtemp1=map64q(tps_data); %%����ӳ��
 tps_symbol= modtemp1*3888*20;

%  tps_symbol(tps_position) = 1;
%  plot(tps_symbol(1:1000));
%  set(gca,'YLim',[0 3]);
 
%%data
start_pos = 1;
start_pos_1 = 1;
data_transfer = zeros(1,sim_num*FFT_len);
data_start_pos = 1;
for i=1:sim_num
    data_x = randi([0 1],1,FFT_len*BitPerSym);
    modtemp1=map64q(data_x); %%����ӳ��
    modtemp= modtemp1*3888*20;
    modtemp(tps_position+mod(i,dimY)*dimX_len)= tps_symbol;
    temp_t1=ifft(modtemp, FFT_len);
    data_transfer(data_start_pos:data_start_pos+FFT_len-1)=modtemp;
    data_start_pos = data_start_pos + FFT_len;
    
    frm_len = Frame_len;
    data_aft_map_tx1(start_pos:start_pos+frm_len-1)=[PN temp_t1];
    start_pos = start_pos+frm_len;
    
    frm_len_1 = FFT_len+DPN_total_len;
    data_aft_map_tx2(start_pos_1:start_pos_1+frm_len_1-1)=[DPN DPN temp_t1];
    start_pos_1 = start_pos_1+frm_len_1;
end

Send_data_srrc_tx1 = data_aft_map_tx1;
Send_data_srrc_tx1_ch_spn = filter(channelFilter,1,Send_data_srrc_tx1);%���ŵ�
Send_data_srrc_tx1_spn = awgn(Send_data_srrc_tx1_ch_spn,SNR_IN,'measured');

Send_data_srrc_tx2 = data_aft_map_tx2;
Send_data_srrc_tx1_ch_dpn = filter(channelFilter,1,Send_data_srrc_tx2);%���ŵ�
Send_data_srrc_tx1_dpn = awgn(Send_data_srrc_tx1_ch_dpn,SNR_IN,'measured');

matfilename = strcat('DTMB_data_awgn_SNR',num2str(SNR_IN),'.mat');
if debug_multipath
    matfilename = strcat('DTMB_data_multipath_new',num2str(debug_path_type),'SNR',num2str(SNR_IN),'.mat');
end
save(matfilename,'Send_data_srrc_tx1_spn','Send_data_srrc_tx1_ch_spn','Send_data_srrc_tx1_ch_dpn','Send_data_srrc_tx1_dpn','data_transfer','tps_position',...
'tps_symbol','Super_Frame','tps_block_len','dimY','dimX_len');

end