function [EEG, Cfg] = CTAP_sweep(EEG, Cfg)
%CTAP_sweep - A CTAP wrapper functions for HYDRA-parameter sweeping
%
% Description:
%
% Syntax:
%   [EEG, Cfg] = CTAP_sweep(EEG, Cfg);
%
% Inputs:
%   EEG         struct, EEGLAB structure
%   Cfg         struct, CTAP configuration structure
%
% Outputs:
%   EEG         struct, EEGLAB structure modified by this function
%   Cfg         struct, Cfg struct should be updated with parameter values
%                       actually used
%
% Notes: 
%
% See also: 
%
% Copyright(c) 2017 FIOH:
% Benjamin Cowley (Benjamin.Cowley@ttl.fi), Jussi Korpela (jussi.korpela@ttl.fi)
%
% This code is released under the MIT License
% http://opensource.org/licenses/mit-license.php
% Please see the file LICENSE for details.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Perform checks.
if ~isfield(Cfg.ctap.sweep, 'function')
    error('CTAP_sweep:bad_params', 'Must define target function to sweep!')
end
if ~isfield(Cfg.ctap.sweep, 'sweep_param')
    error('CTAP_sweep:bad_params', 'Must define target parameter to sweep!')
end
if ~isfield(Cfg.ctap.sweep, Cfg.ctap.sweep.sweep_param)
    error('CTAP_sweep:bad_params'...
        , 'Must define set or range of target parameter values to sweep over!')
end


%% create Arg and assign any defaults to be chosen at the CTAP_ level
Arg = struct;
% check and assign the defined parameters to structure Arg, for brevity
if isfield(Cfg.ctap, 'sweep')
    Arg = joinstruct(Arg, Cfg.ctap.sweep);%override with user params
end


%% ASSIST
% If not given, Build the pseudo-pipe for sweeping config
if ~isfield(Arg, 'SWPipe')
    SWPipe.funH = {@Arg.function,...
                   @CTAP_reject_data };
    SWPipe.id = '1_swept';
else
    SWPipe = Arg.SWPipe;
end
if ~isfield(Arg, 'SWPipeParams')
    param_field = strrep(Arg.function, 'CTAP_', '');
    SWPipeParams.(param_field).method = Cfg.ctap.(param_field).method;
else
    SWPipeParams = Arg.SWPipeParams;
end

SweepParams.funName = Arg.function;
SweepParams.paramName = Arg.sweep_param;
SweepParams.values = num2cell(Arg.(Arg.sweep_param));



%% CORE - SWEEP THE LEG!
[SWEEG, PARAMS] = CTAP_pipeline_sweeper(EEG...
                        , SWPipe, SWPipeParams, Cfg, SweepParams); %#ok<*ASGLU>

% save(fullfile(PARAM.path.sweepresDir...
%     , sprintf('sweepres_%s.mat', Cfg.MC.measurement(k).casename))...
%     , 'SWEEG', 'PARAMS','SWPipe','PipeParams', 'SweepParams', '-v7.3')


% TODO: REWRITE THIS ANALYSIS CODE TO WORK HERE...
%Number of blink related components
n_sweeps = numel(SWEEG);
dmat = NaN(n_sweeps, 2);
cost_arr = NaN(n_sweeps, 1);

ep_win = [-1, 1]; %sec
ch_inds = horzcat(78:83, 91:96); %frontal
EEGclean.event = EEGprepro.event;
EEG_clean_ep = pop_epoch( EEGclean, {'blink'}, ep_win);

tmp_savedir = fullfile(PARAM.path.sweepresDir, k_id);
mkdir(tmp_savedir);
for i = 1:n_sweeps
    dmat(i,:) = [SweepParams.values{i},...
                numel(SWEEG{i}.CTAP.badchans.variance.chans) ];
    fprintf('mad: %1.2f, n_chans: %d\n', dmat(i,1), dmat(i,2));

    % PLOT BAD CHANS
    figh = ctaptest_plot_bad_chan(EEGprepro...
        , 'badness', get_eeg_inds(EEGprepro, SWEEG{i}.CTAP.badchans.variance.chans)...
        , 'sweep_i', i...
        , 'savepath', tmp_savedir); %#ok<*NASGU>
end
%plot(cost_arr, '-o')

figH = figure();
plot(dmat(:,1), dmat(:,2), '-o');
xlabel('MAD multiplication factor');
ylabel('Number of artefactual channels');
saveas(figH, fullfile(PARAM.path.sweepresDir,...
        sprintf('sweep_N-bad-chan_%s.png', k_id)));
close(figH);


% Test quality of identifications
th_value = 2;
th_idx = find( [SweepParams.values{:}] <= th_value , 1, 'last' );

% channels identified as artifactual which are actually clean
setdiff(SWEEG{th_idx}.CTAP.badchans.variance.chans, ...
        EEG.CTAP.artifact.variance_table.name)

% wrecked channels not identified
tmp2 = setdiff(EEG.CTAP.artifact.variance_table.name, ...
        SWEEG{th_idx}.CTAP.badchans.variance.chans);

chm = ismember(EEG.CTAP.artifact.variance_table.name, tmp2);
EEG.CTAP.artifact.variance_table(chm,:)  


%% Finally, set the relevant parameter field of target function to be 'result'
Cfg.ctap.(Arg.function).(Arg.sweep_param) = result;


%% ERROR/REPORT
%... the complete parameter set from the function call ...
Cfg.ctap.sweep = Arg;
%log outcome to console and to log file
msg = myReport(sprintf('HYDRA has swept function %s in parameter %s.',...
    Arg.function, Arg.sweep_param), Cfg.env.logFile);
%create a history element
EEG.CTAP.history(end+1) = create_CTAP_history_entry(msg, mfilename, Arg);