% Bradley Voytek
% Copyright (c) 2010
% University of California, Berkeley
% Helen Wills Neuroscience Institute

% GET PAC
% load('raw_data.mat'); % Data is 2D array with each row containing the raw timeseries for each channel
raw_data = reshape(allERP{trialType}', 1, size(allERP{trialType},1)*size(allERP{trialType},2));

% Put data in common average reference
ref = mean(raw_data, 1);
for x = 1:size(raw_data, 1)
    raw_data(x, :) = raw_data(x, :) - ref;
end
clear x ref
 
low_frequency = [4 8; 8 12]; % define theta and alpha bands
high_frequency = [80 150]; % define gamma band
sampling_rate = 1000; % define sampling rate

% Initialize PAC variable
pac = zeros([size(raw_data, 1) size(low_frequency, 1) size(high_frequency, 1)]);

% Calculate PAC
for chanIt = 1:size(raw_data, 1)
    signal = raw_data(chanIt, :);
 
    for lowIt = 1:size(low_frequency, 1)
        tic
        disp(['Channel ' num2str(chanIt) ' Low Frequency ' num2str(lowIt)]);
        
        % Extract low frequency analytic phase
        low_frequency_phase = eegfilt(signal, sampling_rate, low_frequency(lowIt, 1), []);
        low_frequency_phase = eegfilt(low_frequency_phase, sampling_rate, [], low_frequency(lowIt, 2));
        low_frequency_phase = angle(hilbert(low_frequency_phase));
 
        for highIt = 1:size(high_frequency, 1)
            % Extract low frequency analytic phase of high frequency analytic amplitude
            high_frequency_phase = eegfilt(signal, sampling_rate, high_frequency(highIt, 1), []);
            high_frequency_phase = eegfilt(high_frequency_phase, sampling_rate, [], high_frequency(highIt, 2));
            high_frequency_phase = abs(hilbert(high_frequency_phase));
            high_frequency_phase = eegfilt(high_frequency_phase, sampling_rate, low_frequency(lowIt, 1), []);
            high_frequency_phase = eegfilt(high_frequency_phase, sampling_rate, [], low_frequency(lowIt, 2));
            high_frequency_phase = angle(hilbert(high_frequency_phase));
 
            % Calculate PAC
            pac(chanIt, lowIt, highIt) =...
                abs(sum(exp(1i * (low_frequency_phase - high_frequency_phase)), 'double'))...
                / length(high_frequency_phase);
                
            clear high_frequency_phase
        end
        clear highIt low_frequency_phase
        toc
    end
    clear signal lowIt
end
clear chanIt
 


% GET PEAK/TROUGH

% Define window around peaks and troughs to average gamma power
percent_window_size = 0.05; % +/- 5 percent window around peaks and troughs
window_size(1) = round(sampling_rate / ((low_frequency(1, 1) + low_frequency(1, 2)) / 2) .* percent_window_size);
window_size(2) = round(sampling_rate / ((low_frequency(2, 1) + low_frequency(2, 2)) / 2) .* percent_window_size);
clear percent_window_size

for x = 1:size(raw_data, 1)
    % Extract high frequency analytic amplitude
    high_frequency_amplitude = eegfilt(raw_data(x, :), sampling_rate, high_frequency(1), []);
    high_frequency_amplitude = eegfilt(high_frequency_amplitude, sampling_rate, [], high_frequency(2));
    high_frequency_amplitude = abs(hilbert(high_frequency_amplitude));

    % Extract low frequency analytic phase
    low_frequency_phase = eegfilt(raw_data(x, :), sampling_rate, low_frequency(1, 1), []);
    low_frequency_phase = eegfilt(low_frequency_phase, sampling_rate, [], low_frequency(1, 2));
    low_frequency_phase = angle(hilbert(low_frequency_phase));

    % Find peaks and troughs
    thetaTroughEvents = find(low_frequency_phase < -(pi - 0.01));
    thetaPeakEvents = find((low_frequency_phase < (0 + 0.005)) & (low_frequency_phase > (0 - 0.005)));
    thetaTroughEvents = thetaTroughEvents(thetaTroughEvents > 20);
    thetaTroughEvents = thetaTroughEvents(thetaTroughEvents < (length(low_frequency_phase)-20));
    thetaPeakEvents = thetaPeakEvents(thetaPeakEvents > 20);
    thetaPeakEvents = thetaPeakEvents(thetaPeakEvents < (length(low_frequency_phase)-20));
    clear low_frequency_phase

    % Extract low frequency analytic phase
    low_frequency_phase = eegfilt(raw_data(x, :), sampling_rate, low_frequency(2, 1), []);
    low_frequency_phase = eegfilt(low_frequency_phase, sampling_rate, [], low_frequency(2, 2));
    low_frequency_phase = angle(hilbert(low_frequency_phase));

    % Find peaks and troughs
    alphaTroughEvents = find(low_frequency_phase < -(pi - 0.01));
    alphaPeakEvents = find((low_frequency_phase < (0 + 0.005)) & (low_frequency_phase > (0 - 0.005)));
    alphaTroughEvents = alphaTroughEvents(alphaTroughEvents > 20);
    alphaTroughEvents = alphaTroughEvents(alphaTroughEvents < (length(low_frequency_phase)-20));
    alphaPeakEvents = alphaPeakEvents(alphaPeakEvents > 20);
    alphaPeakEvents = alphaPeakEvents(alphaPeakEvents < (length(low_frequency_phase)-20));
    clear low_frequency_phase
    
    % Calculate power around peaks/troughs
    troughPower(x, 1) = mean(ERP(high_frequency_amplitude, sampling_rate, thetaTroughEvents, window_size(1), window_size(1)));
    troughPower(x, 2) = mean(ERP(high_frequency_amplitude, sampling_rate, alphaTroughEvents, window_size(2), window_size(2)));
    peakPower(x, 1) = mean(ERP(high_frequency_amplitude, sampling_rate, thetaPeakEvents, window_size(1), window_size(1)));
    peakPower(x, 2) = mean(ERP(high_frequency_amplitude, sampling_rate, alphaPeakEvents, window_size(2), window_size(2)));
    clear high_frequency_amplitude *Events
end
clear x *freq* raw_data samp* window_size


%%
% THE FOLLOWING IS THE CODE USED TO GENERATE ERPS

function [ERP_mean, ERP_mat, ERP_prc, ERP_prcmat] = ERP(data, srate, event_ind, before, after, wholeMatrix, baselineWindow, calcPercent)

%
% function [ERP_mean, ERP_mat, ERP_prc, ERP_prcmat] = ERP(data, srate, event_ind, before, after, wholeMatrix, baselineWindow, calcPercent)
% Usage: [ERP_mean, ERP_mat, ERP_prc, ERP_prcmat] = ERP(EEG.data(1, :), EEG.srate, eventPoints, 100, 500, 1, [-100 0], 1)
%
% This script just creates an ERP for a single channel of data, used for
% time series data and analytic amplitude for frequency data. If a value is
% provided for baselineWindow, then the outputs for ERP_mean and ERP_mat
% are both baseline-corrected. If a baseline is given *and* calcPercent == 1 then
% an output for ERP_prc and ERP_prcmat is calculated.
%
% This function requires 6 inputs, but can accept 8:
% data: A single channel of continuous EEG data (e.g., EEG.data(1, :) for EEGLAB-formatted data
% srate: sampling rate of the input data (e.g., EEG.srate for EEGLAB data)
% event_ind: a vector containing the timepoints for the time-locking event
%    (e.g., [1034 2133 4681 9960 12574] means that your events of interest started at those indices of EEG.data(1, :))
% before: the amount of time (in ms) before the time-locking event you wish to include in your ERSP
% after: the amount of time (in ms) after the time-locking event you wish to include in your ERSP
% wholeMatrix: output the whole matrix with each event, or just the ERP
% baselineWindow: defines the baseline window, relative to the event-locking onset to remove the mean baseline from the data (e.g., to
%     define a baseline window from 100 ms before to the event-locking onset, use [-100 0]), and to use as a reference for calculating
%     percent signal change
% calcPercent: whether or not to calculate percent signal change
%
% This function returns 2 pieces of data, 4 if calcPercent == 1:
% ERP_mean: the ERP, which is just the mean of ERP_mat across trials
% ERP_mat: a two-dimensional matrix of equal-length time series around an
% event (ERP_mean is just the mean of ERP_mat across event), only given if
% wholeMatrix == 1
% ERP_prc: the percent signal change relative to baseline ERP, which is
%    just the mean  of ERP_prcmat across trials
% ERP_prcmat: a two-dimensional matrix of equal-length time series of signal
%   change relative to baseline around an event, only given if wholeMatrix == 1
% 
% Lavi Secundo & Adeen Flinker
% Modified by Bradley Voytek
% Copyright (c) 2008
% University of California, Berkeley
% Helen Wills Neuroscience Institute

if nargin < 6
    wholeMatrix = 0;
end

if nargin < 7
    baselineWindow = [];
end

if isempty(baselineWindow)
    calcPercent = 0;
end

% Define time window around event
after_ind = round((after / 1000) * srate);
before_ind = round((before / 1000) * srate);

if ~isempty(baselineWindow)
    % Convert data point indices to ms to find baseline indices relative to event onset
    times = [-before_ind:-1 0 1:after_ind];
    times = (times * 1000) / srate;
    
    % Calculate baseline and convert baseline data point indices to ms
    base_ind = round((baselineWindow / 1000) * srate);
    base_ind = find(times == 0) + base_ind;
end

% Initialize
ERP_mean = zeros(1, round(before_ind + after_ind + 1));

if wholeMatrix == 1
    % Initialize
    ERP_mat = zeros(length(event_ind), round(before_ind + after_ind + 1));
    
    if calcPercent == 1
        % Initialize
        ERP_prcmat = zeros(length(event_ind), round(before_ind + after_ind + 1));
    end

    % Create 3-d matrix with data broken into epochs of equal time window around event
    for i = 1:length(event_ind)
        % Get events
        ERP_mat(i, :) = data(:, round(event_ind(i) - before_ind):round(event_ind(i) + after_ind));
        
        if ~isempty(baselineWindow)
            ERP_mat(i, :) = ERP_mat(i, :) - mean(ERP_mat(i, base_ind(1):base_ind(2)), 2);
        end

        % Calculate % signal change from baseline
        if calcPercent == 1
            temp = data(:, round(event_ind(i) - before_ind):round(event_ind(i) + after_ind));
            baseMean = mean(temp(base_ind(1):base_ind(2)));

            ERP_prcmat(i, :) = ((temp - baseMean) ./ baseMean) .* 100;

            clear temp baseMean
        end
    end
    
    % Average across epochs
    ERP_mean(:, :) = squeeze(mean(ERP_mat, 1));
    
    if calcPercent == 1
        ERP_prc = mean(ERP_prcmat, 1);
    end
    
else
    % Get events
    % Unwind the loops
    % I know it looks goofy, but when you loop through this part >1000000 during the surrogate runs, the fewer times the loop
    % runs, the faster this analysis gets done!
    for i = 1:mod(length(event_ind), 20)
        ERP_mean = ERP_mean + data(:, round(event_ind(i) - before_ind):round(event_ind(i) + after_ind));
    end
    
    for i = (mod(length(event_ind), 20) + 1):20:length(event_ind)
        ERP_mean = ERP_mean...
            + data(:, round(event_ind(i + 0) - before_ind):round(event_ind(i + 0) + after_ind)) + data(:, round(event_ind(i + 1) - before_ind):round(event_ind(i + 1) + after_ind))...
            + data(:, round(event_ind(i + 2) - before_ind):round(event_ind(i + 2) + after_ind)) + data(:, round(event_ind(i + 3) - before_ind):round(event_ind(i + 3) + after_ind))...
            + data(:, round(event_ind(i + 4) - before_ind):round(event_ind(i + 4) + after_ind)) + data(:, round(event_ind(i + 5) - before_ind):round(event_ind(i + 5) + after_ind))...
            + data(:, round(event_ind(i + 6) - before_ind):round(event_ind(i + 6) + after_ind)) + data(:, round(event_ind(i + 7) - before_ind):round(event_ind(i + 7) + after_ind))...
            + data(:, round(event_ind(i + 8) - before_ind):round(event_ind(i + 8) + after_ind)) + data(:, round(event_ind(i + 9) - before_ind):round(event_ind(i + 9) + after_ind))...
            + data(:, round(event_ind(i + 10) - before_ind):round(event_ind(i + 10) + after_ind)) + data(:, round(event_ind(i + 11) - before_ind):round(event_ind(i + 11) + after_ind))...
            + data(:, round(event_ind(i + 12) - before_ind):round(event_ind(i + 12) + after_ind)) + data(:, round(event_ind(i + 13) - before_ind):round(event_ind(i + 13) + after_ind))...
            + data(:, round(event_ind(i + 14) - before_ind):round(event_ind(i + 14) + after_ind)) + data(:, round(event_ind(i + 15) - before_ind):round(event_ind(i + 15) + after_ind))...
            + data(:, round(event_ind(i + 16) - before_ind):round(event_ind(i + 16) + after_ind)) + data(:, round(event_ind(i + 17) - before_ind):round(event_ind(i + 17) + after_ind))...
            + data(:, round(event_ind(i + 18) - before_ind):round(event_ind(i + 18) + after_ind)) + data(:, round(event_ind(i + 19) - before_ind):round(event_ind(i + 19) + after_ind));
    end
    
    % Calculate ERP
    ERP_mean = ERP_mean ./ length(event_ind);
end

% Remove baseline
if ~isempty(baselineWindow)
    ERP_mean = ERP_mean - mean(ERP_mean(base_ind(1):base_ind(2)));
end

