function [EEG, Cfg] = CTAP_detect_bad_channels(EEG, Cfg)
%CTAP_detect_bad_channels  - Autodetect bad quality channels
%
% Description:
%   Requires channel locations and types. These can be added using
%   CTAP_load_chanlocs().
%
% Syntax:
%   [EEG, Cfg] = CTAP_detect_bad_channels(EEG, Cfg);
%
% Inputs:
%   EEG         struct, EEGLAB structure
%   Cfg         struct, CTAP configuration structure
%   Cfg.ctap.detect_bad_channels:
%   .channels       cellstring, A list of channels which should be
%                   analyzed, overrides .channelType, default: field does
%                   not exist
%   .channelType    string or cellstring, A list of channel type string that
%                   specify which channels are to be analyzed, default: 'EEG'
%   .orig_ref       cellstring, Original reference channels, needed by some
%                   methods that rereference the data, default: Cfg.eeg.reference
%   .refChannel     cellstring, {'Fz'}
%   .refChannel     cellstring, reference channel name for FASTER
%                   default: get_refchan_inds(EEG, 'frontal')
%   .method         string, Detection method, see
%                   ctapeeg_detect_bad_channels.m for available methods.
%
% Outputs:
%   EEG         struct, EEGLAB structure modified by this function
%   Cfg         struct, Cfg struct is updated by parameters,values actually used
%
% Notes: 
%
% See also: ctapeeg_detect_bad_channels()
%
% Copyright(c) 2015 FIOH:
% Benjamin Cowley (Benjamin.Cowley@ttl.fi), Jussi Korpela (jussi.korpela@ttl.fi)
%
% This code is released under the MIT License
% http://opensource.org/licenses/mit-license.php
% Please see the file LICENSE for details.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Set optional arguments
Arg.channelType = 'EEG';
if isfield(Cfg.eeg, 'reference')
    Arg.orig_ref = Cfg.eeg.reference;
end
if isfield(Cfg.eeg, 'chanlocs')
    Arg.refChannel = {EEG.chanlocs(get_refchan_inds(EEG, 'frontal')).labels};
end

% Override defaults with user parameters
if isfield(Cfg.ctap, 'detect_bad_channels')
    Arg = joinstruct(Arg, Cfg.ctap.detect_bad_channels); %override w user params
end

%% ASSIST
if ~isfield(Arg, 'channels')
    Arg.channels = find(ismember({EEG.chanlocs.type}, Arg.channelType));
end

% Check that given channels are EEG channels
if isempty(Arg.channels) ||...
        sum(strcmp('EEG', {EEG.chanlocs.type})) < length(Arg.channels)
    myReport(['WARN CTAP_detect_bad_channels:: '...
        'EEG channel type has not been well defined,'...
        ' or given channels are not all EEG!'], Cfg.env.logFile);
end


%% CORE
[EEG, params, result] = ctapeeg_detect_bad_channels(EEG, Arg);

Arg = joinstruct(Arg, params);

%% PARSE RESULT
% Checking and fixing
if ~isfield(EEG.CTAP, 'badchans') 
    EEG.CTAP.badchans = struct;
end
if ~isfield(EEG.CTAP.badchans, Arg.method) 
    EEG.CTAP.badchans.(Arg.method) = result;
else
    EEG.CTAP.badchans.(Arg.method)(end+1) = result;
end

% save the index of the badness for the CTAP_reject_data() function
if isfield(EEG.CTAP.badchans,'detect')
    EEG.CTAP.badchans.detect.src = [EEG.CTAP.badchans.detect.src;...
        {Arg.method, length(EEG.CTAP.badchans.(Arg.method))}];
    [numbad, ~] = ctap_read_detections(EEG, 'badchans');
    numbad = numel(numbad);
else
    EEG.CTAP.badchans.detect.src =...
        {Arg.method, length(EEG.CTAP.badchans.(Arg.method))};
    numbad = numel(result.chans);
end

% parse and describe results
repstr1 =...
    sprintf('Bad channels by ''%s'' for ''%s'': ', Arg.method, EEG.setname);
repstr2 = {result.chans}; %just found bad chans
% repstr2 = {EEG.CTAP.badchans.(Arg.method).chans}; %all bad chans by Arg.method

prcbad = 100 * numbad / EEG.nbchan;
if prcbad > 10
    repstr1 = ['WARN ' repstr1];
end
repstr3 = sprintf('\nTOTAL %d/%d = %3.1f prc of channels marked to reject\n'...
    , numbad, EEG.nbchan, prcbad);

EEG.CTAP.badchans.detect.prc = prcbad;


%% ERROR/REPORT
Cfg.ctap.detect_bad_channels = Arg;

msg = myReport({repstr1 repstr2 repstr3}, Cfg.env.logFile);

EEG.CTAP.history(end+1) = create_CTAP_history_entry(msg, mfilename, Arg);
