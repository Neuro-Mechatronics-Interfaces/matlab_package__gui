function T = check_trial_xy_trajs(SUBJ, YYYY, MM, DD, varargin)
%CHECK_TRIAL_XY_TRAJS  GUI to check trials based on position x/y trajectories for center-out task.
%
% Syntax:
%   T = gui.check_trial_xy_trajs(SUBJ, YYYY, MM, DD);
%   T = gui.check_trial_xy_trajs(___, 'Name', value, ...);
%
% Inputs:
%   First 4 arguments refer to the recording session:
%   SUBJ - e.g. "Spencer"
%   YYYY - e.g. 2022
%   MM   - e.g. 12
%   DD   - e.g. 8
%
%   varargin - (Optional) 'Name',value input argument pairs.
%
% Output:
%   T - Trial Data table with updated exclusions. Still needs to be saved
%           to generated_data in the corresponding generated data "tank."
%           The "excluded_by_pots" column will be updated based on scoring
%           from this GUI.
%
% See also: Contents, io.read_events, io.load_wrist_event_table_trial,
%               enum.TargetAngle, enum.TaskTarget

pars = struct;
pars.CData = struct('MID', [0.1 0.1 0.9], ...
                    'PRO', [0.2 0.6 0.8]);   % Color trials by orientation
pars.LayoutHandle = []; % Can be an input graphics tiledlayout handle.
pars.XLim = [-30, 30];  % Degrees
pars.YLim = [-30, 30];  % Degrees
pars.TLim = [-60, 500]; % milliseconds to plot (centered on detected MOVE onset) 
pars.AxesOrder = [6, 3, 2, 1, 4, 7, 8, 9]; % First element is the 3:00 target, and so forth (see: enum.TargetAngle)
pars.SampleRate = 4000; % Sample rate (Hz)

[pars.raw_data_folder, pars.generated_data_folder] = parameters('raw_data_folder', 'generated_data_folder');

if istable(SUBJ)
    switch nargin
        case 2
            error("Invalid input combination: if first argument is a table, must provide subsequent arguments as <'Name', value> pairs.");
        case 3
            varargin = {YYYY, MM};
        case 4
            error("Invalid input combination: if first argument is a table, must provide subsequent arguments as <'Name', value> pairs.");
        otherwise
            varargin = [YYYY, MM, DD, varargin];
    end
    T = SUBJ;
    SUBJ = T.subject(1);
    YYYY = year(T.date(1));
    MM = month(T.date(1));
    DD = day(T.date(1));
    pars = utils.parse_parameters(pars, varargin{:});
else
    pars = utils.parse_parameters(pars, varargin{:});
    T = io.read_events(SUBJ, YYYY, MM, DD, ...
        'generated_data_folder', pars.generated_data_folder, ...
        'raw_data_folder', pars.raw_data_folder);
end

fs = pars.SampleRate * 1e-3; % samples/millisecond (for scaling)
relative_sample_indices = (pars.TLim(1)*fs):(pars.TLim(2)*fs);

if isempty(pars.LayoutHandle)
    fig = figure(...
        'Name', 'Individual-Trial Checker', ...
        'Color', 'w', ...
        'Position',[547   120   830   767]);
    L = tiledlayout(fig, 3, 3);
else
    L = pars.LayoutHandle;
    fig = L.Parent;
end

tank = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
excluded_blocks = [];

ax = nexttile(L, 5);
set(ax, 'NextPlot', 'add', 'FontName', 'Tahoma', 'XColor', 'none', 'YColor', 'none');
title(ax, 'Rejections','FontName','Tahoma','Color','k');

N = size(T,1);
N_base = sum(T.outcome==enum.TaskOutcome.UNSUCCESSFUL);
exc_str = text(ax, 0.25, 0.5, sprintf("%d / %d", N_base, N), 'FontName', 'Tahoma','Color','r');
title(L, 'Trajectories', strrep(tank, '_', '-'), 'FontName','Tahoma','Color','k');

for ii = 1:8
    ax = nexttile(L, pars.AxesOrder(ii));
    set(ax,...
        'Box', 'on', ...
        'NextPlot', 'add', ...
        'FontName', 'Tahoma', ...
        'XColor', 'k', ...
        'YColor', 'k', ...
        'XLim', pars.XLim, ...
        'YLim', pars.YLim);
    Tsub = T((T.target_index == enum.TaskTarget(ii-1)) & (T.outcome == enum.TaskOutcome.SUCCESSFUL),:);
    fprintf(1,'\t->\t<strong>%s</strong>\n\t\t->\t', string(enum.TaskTarget(ii-1)));
    trial = io.load_wrist_event_table_trial(Tsub);
    for ik = 1:numel(trial)
        idx = find(trial{ik}.sync(1,:) >= 16, 1, 'first');
        if isempty(idx)
            fprintf(1,'No MOVE ONSET detected for %s: %s-%d\n', tank, string(enum.TaskTarget(ii-1)), ik);
            excluded_blocks(end+1) = Tsub.block(ik); %#ok<AGROW> 
        else
            vec = idx + relative_sample_indices;
            vec((vec < 1) | (vec > numel(trial{ik}.x))) = [];
            c = pars.CData.(string(enum.TaskOrientation(Tsub.orientation(ik))));
            line(ax, trial{ik}.x(vec), trial{ik}.y(vec), ...
                'Color', c, ...
                'LineStyle', '-', ...
                'UserData', struct('block', Tsub.block(ik), 'c', c), ...
                'ButtonDownFcn', @add_remove_excluded);
        end
    end
end


waitfor(fig);
T.excluded_by_pots(ismember(T.block, excluded_blocks)) = true;

function add_remove_excluded(src,~)
    if ismember(src.UserData.block, excluded_blocks)
        excluded_blocks = setdiff(excluded_blocks, src.UserData.block);
        set(src, 'LineStyle', '-', 'Color', src.UserData.c);
    else
        excluded_blocks(end+1) = src.UserData.block;
        set(src, 'LineStyle', ':', 'Color', 'r');
    end
    set(exc_str, 'String', sprintf("%d / %d", N_base + numel(excluded_blocks), N));
    drawnow;
end

end