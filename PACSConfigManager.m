classdef PACSConfigManager
    %PACSConfigManager Persistent Configuration Storage for PACS Dialog
    % PACSConfigManager provides persistent storage functionality for PACS
    % server configurations across application instances.
    % This class uses MATLAB's persistent variables to maintain
    % configuration data in memory during a MATLAB session.
    %
    % Syntax:
    %   config = PACSConfigManager.managePersistentConfig('get')
    %   config = PACSConfigManager.managePersistentConfig('set', newConfig)

    %   Copyright 2026 The MathWorks, Inc.

    methods (Static)
        function config = managePersistentConfig(action, newConfig)
            % Manage persistent configuration using persistent variable
            % This allows configuration to persist across app instances
            %
            % Inputs:
            %   action - 'get' to retrieve config, 'set' to save config
            %   newConfig - Configuration structure (only used with 'set')
            %
            % Output:
            %   config - Retrieved or saved configuration structure

            persistent savedConfig

            switch action
                case 'set'
                    % Save new configuration
                    savedConfig = newConfig;
                    config = savedConfig;

                case 'get'
                    % Retrieve saved configuration
                    if isempty(savedConfig)
                        config = struct();
                    else
                        config = savedConfig;
                    end
            end
        end
    end
end