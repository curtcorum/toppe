function [isValid, gmax, slewmax] = checkwaveforms(varargin)
% Check rf/gradient waveforms against system limits.
%
% function isValid = checkwaveforms(varargin)
%
% Inputs:
%  system       (required) struct containing hardware specs. See systemspecs.m
%
% Options 
%  rf           rf waveform
%  gx/gy/gz     gradient waveform
%  rfUnit       Gauss (default) or mT
%  gradUnit     Gauss/cm (default) or mT/m
%
% Outputs
%  isValid    boolean/logical (true/false)
%  gmax       [1 3] Max gradient amplitude on the three gradient axes (x, y, z) (<gradUnit>)
%  slewmax    [1 3] Max slew rate on the three gradient axes (x, y, z) (G/cm/ms) (<gradUnit>/ms)

import toppe.*
import toppe.utils.*

%% parse inputs

% Defaults
arg.rf = [];
arg.gx = [];
arg.gy = [];
arg.gz = [];
arg.rfUnit   = 'Gauss';
arg.gradUnit = 'Gauss/cm';
arg.system = [];

arg = toppe.utils.vararg_pair(arg, varargin);

if isempty(arg.system)
    error('Missing system argument');
end

system = arg.system;

%% Copy input waveform to rf, gx, gy, and gz (so we don't have to carry the arg. prefix around)
fields = {'rf' 'gx' 'gy' 'gz'};
for ii = 1:length(fields)
	wavtype = fields{ii};
	cmd = sprintf('%s = %s;', wavtype, sprintf('arg.%s', wavtype));
	eval(cmd);
end

%% Convert input waveforms to Gauss and Gauss/cm
if strcmp(arg.rfUnit, 'mT')
	rf = rf/100;   % Gauss
end
if strcmp(arg.gradUnit, 'mT/m')
	gx = gx/10;    % Gauss/cm
	gy = gy/10;
	gz = gz/10;
end

%% Convert system limits to Gauss and Gauss/cm
if strcmp(system.rfUnit, 'mT')
	system.maxRf = system.maxRf/100;      % Gauss
end
if strcmp(system.gradUnit, 'mT/m')
	system.maxGrad = system.maxGrad/10;   % Gauss/cm
end
if strcmp(system.slewUnit, 'T/m/s')
	system.maxSlew = system.maxSlew/10;   % Gauss/cm/msec
end

%% Check against system hardware limits
isValid = true;

tol = 1;     %

grads = 'xyz';

% gradient amplitude
for ii = 1:3
	cmd = sprintf('gmtmp = max(abs(g%s(:)));', grads(ii)); 
	eval(cmd);
    if isempty(gmtmp)
        gmax(ii) = 0;
    else
        gmax(ii) = gmtmp;
	    if gmax(ii) > system.maxGrad
	    	fprintf('Error: %s gradient amplitude exceeds system limit (%.1f%%)\n', grads(ii), gmax(ii)/system.maxGrad*100);
	    	isValid = false;
	    end
    end
end

% gradient slew
for ii = 1:3
	cmd = sprintf('smtmp = max(abs(diff(g%s/(system.raster*1e3))));', grads(ii));
	eval(cmd);
    if isempty(smtmp)
        slewmax(ii) = 0;
    else
        slewmax(ii) = smtmp;
	    if slewmax(ii) > system.maxSlew
		    fprintf('Error: %s gradient slew rate exceeds system limit (%.1f%%)\n', grads(ii), slewmax(ii)/system.maxSlew*100);
		    isValid = false;
        end
	end
end

% rf
maxRf = max(abs(rf));
if maxRf > system.maxRf
	fprintf('Error: rf amplitude exceeds system limit (%.1f%%)\n', maxRf/system.maxRf*100);
	isValid = false;
end

%% Is (max) waveform duration on a 4 sample (16us) boundary?
ndat = max( [size(rf,1) size(gx,1) size(gy,1) size(gz,1)] );
if mod(ndat, 4)
	fprintf('Error: waveform duration must be on a 4 sample (16 us) boundary.');
	isValid = false;
end

%% do all waveforms start and end at zero?
for ii = 1:3
	eval(sprintf('if isempty(g%s); g%s = 0; end', grads(ii), grads(ii)));
end
if isempty(rf)
	rf = 0;
end
if any([gx(1,:) gx(end,:) gy(1,:) gy(end,:) gz(1,:) gz(end,:) rf(1,:) rf(end,:)] ~= 0)
	fprintf('Error: all waveforms must begin and end with zero\n')
	isValid = false;
end

return;
