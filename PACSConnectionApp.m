classdef PACSConnectionApp < matlab.apps.App
    %PACSCONNECTIONAPP DICOM PACS Server Query and Retrieve Interface
    %   PACSConnectionApp provides a graphical user interface for
    %   connecting to Picture Archiving and Communication System (PACS)
    %   servers to query and retrieve medical imaging data using the DICOM
    %   protocol.
    %   
    %   PACSConnectionApp() opens a standalone PACS Connection App window
    %   for querying and retrieving DICOM data from PACS servers.
    %   
    %   PACSConnectionApp('OpenedFromApp', true) creates the dialog in
    %   app-integrated mode, where the dialog can be controlled by a parent
    %   application and fires events when data is imported.
    %   
    %   Copyright 2025-2026 The MathWorks, Inc.

    % Used to locate and load the app's XML configuration file
    properties (Access = public, Constant)
        AppConfigFilename = './PACSConnectionApp.xml'; % File path to the app configuration file containing component layout and settings
    end

    % Properties that correspond to app components
    properties (Access = public)
        MainFigure                      matlab.ui.Figure
        MainGridLayout                  matlab.ui.container.GridLayout
        TabGroup                        matlab.ui.container.TabGroup
        ConfigurationTab                matlab.ui.container.Tab
        ConfigurationGridLayout         matlab.ui.container.GridLayout
        TLSTrustedCertBrowseBtn         matlab.ui.control.Button
        TLSCertBrowseButton             matlab.ui.control.Button
        TLSKeyBrowseButton              matlab.ui.control.Button
        EnableTLSLabel                  matlab.ui.control.Label
        ServerAETitleEditField          matlab.ui.control.EditField
        PACSAETitleEditFieldLabel       matlab.ui.control.Label
        ConnectionStatusIcon            matlab.ui.control.Label
        EnableTLSCheckBox               matlab.ui.control.CheckBox
        TLSTrustedCertEditField         matlab.ui.control.EditField
        EditField6Label                 matlab.ui.control.Label
        TLSCertificateEditField         matlab.ui.control.EditField
        CertificateEditFieldLabel       matlab.ui.control.Label
        TLSKeyFileEditField             matlab.ui.control.EditField
        KeyEditFieldLabel               matlab.ui.control.Label
        ServerNameEditField             matlab.ui.control.EditField
        ServerNameEditFieldLabel        matlab.ui.control.Label
        PortNumberEditField             matlab.ui.control.NumericEditField
        PortEditFieldLabel              matlab.ui.control.Label
        HostIPAddressEditField          matlab.ui.control.EditField
        IPaddressEditFieldLabel         matlab.ui.control.Label
        ConnectButton                   matlab.ui.control.Button
        DeleteServerButton              matlab.ui.control.Button
        SaveServerButton                matlab.ui.control.Button
        ClientAETitleEditField          matlab.ui.control.EditField
        MyAETitleEditFieldLabel         matlab.ui.control.Label
        ServerSelectionDropDown         matlab.ui.control.DropDown
        SelectorcreatePACSserverLabel   matlab.ui.control.Label
        QueryRetrieveTab                matlab.ui.container.Tab
        QueryRetrieveGridLayout         matlab.ui.container.GridLayout
        RetrievePanel                   matlab.ui.container.Panel
        RetrieveGridLayout              matlab.ui.container.GridLayout
        DownloadOrImportButton          matlab.ui.control.Button
        StorageDirBrowseButton          matlab.ui.control.Button
        StorageDirEditField             matlab.ui.control.EditField
        StorageDirEditFieldLabel        matlab.ui.control.Label
        QueryResultsTable               matlab.ui.control.Table
        QueryPanel                      matlab.ui.container.Panel
        QueryGridLayout                 matlab.ui.container.GridLayout
        RegistryLabel                   matlab.ui.control.Label
        RunQueryButton                  matlab.ui.control.Button
        QueryParametersTable            matlab.ui.control.Table
        ClearTableButton                matlab.ui.control.Button
        AddFieldButton                  matlab.ui.control.Button
        CommonFieldsDropDown            matlab.ui.control.DropDown
        EndDatePicker                   matlab.ui.control.DatePicker
        StartDatePicker                 matlab.ui.control.DatePicker
        DateRangeDropDown               matlab.ui.control.DropDown
        ContextMenu                     matlab.ui.container.ContextMenu
        DeleteFieldMenu                 matlab.ui.container.Menu
    end


    properties (SetAccess = private)
        % Filepath - Path to downloaded DICOM data (set after successful download)
        Filepath string = [];
    end

    properties (Dependent)
        % Visible - Controls visibility of the dialog window
        Visible
    end

    events
        % ImportIsSuccessful - Fired when data is successfully imported
        % Listeners can access the Filepath property to get download location
        ImportIsSuccessful
    end


    % =====================================================================
    % DATA PROPERTIES
    % =====================================================================
    properties (Access = private)
        % DICOM attributes to retrieve from PACS queries
        % These fields will populate the results table
        DicomFieldsToRetrieve (1,:) string = [...
            "PatientName", "PatientID", "Modality", "StudyDescription", ...
            "StudyInstanceUID", "Rows", "Columns", "SeriesDescription", ...
            "SeriesInstanceUID"]

        % Commonly used DICOM fields for quick selection
        CommonDicomFieldNames (1,:) string = [...
            "PatientID", "PatientName", "PatientSex", "Modality", "Other Field"]

        % Active DICOM connection object
        ActiveDicomConnection   % dicomConnection object

        % Saved PACS server configurations (array of structs)
        SavedServerConfigs struct

        % Currently selected server name
        CurrentServerName (1,1) string

        % Connection status flag
        IsCurrentlyConnected (1,1) logical = false

        % Directory for downloaded DICOM files
        StorageDirectory (1,1) string = tempdir

        % OpenedFromApp - Flag indicating if dialog was opened from another app
        % When true, dialog hides instead of closing to allow reuse
        OpenedFromApp (1,1) logical = false
    end

    % =====================================================================
    % UI TEXT CONSTANTS
    % =====================================================================
    properties (Access = private, Constant)
        % Default values for new server configuration
        ServerNameDefault = "PACS"
        ClientAETitleDefault = "MATLAB_QR"
        ServerAETitleDefault = "ANY-SCP"
        NewServerPlaceholder = "< Add New Server >"
    end

    % =====================================================================
    % CONFIGURATION TAB CALLBACKS
    % =====================================================================
    methods (Access = private)
        function serverNameList = getServerNameList(app)
            % Get list of saved server names plus "Add New Server" option

            serverNameList = app.NewServerPlaceholder;
            if ~isempty(app.SavedServerConfigs)
                serverNameList = [app.SavedServerConfigs.ServerName, serverNameList];
            end
        end

        function populateConfigurationFields(app, serverConfig)
            % Populate configuration fields with saved server data

            app.ServerSelectionDropDown.Value = serverConfig.ServerName;
            app.HostIPAddressEditField.Value = serverConfig.IPAddress;
            app.PortNumberEditField.Value = serverConfig.Port;
            app.ClientAETitleEditField.Value = serverConfig.MyAEtitle;
            app.ServerAETitleEditField.Value = serverConfig.PACSAEtitle;
            app.ServerNameEditField.Value = serverConfig.ServerName;
            app.EnableTLSCheckBox.Value = serverConfig.EnableTLS;
            app.TLSKeyFileEditField.Value = serverConfig.Key;
            app.TLSCertificateEditField.Value = serverConfig.Certificate;
            app.TLSTrustedCertEditField.Value = serverConfig.TrustedCertificate;
            app.DeleteServerButton.Enable = "on";

            % Update TLS row visibility and Connect button state
            updateTLSRowVisibility(app);
            updateConnectButtonState(app);
        end

        function resetConfigurationFields(app)
            % Reset configuration fields to default values

            app.ServerSelectionDropDown.Value = app.NewServerPlaceholder;
            app.HostIPAddressEditField.Value = '';
            app.PortNumberEditField.Value = 0;
            app.ClientAETitleEditField.Value = app.ClientAETitleDefault;
            app.ServerAETitleEditField.Value = app.ServerAETitleDefault;
            app.ServerNameEditField.Value = generateUniqueServerName(app);
            app.EnableTLSCheckBox.Value = true;
            app.TLSKeyFileEditField.Value = '';
            app.TLSCertificateEditField.Value = '';
            app.TLSTrustedCertEditField.Value = '';
            app.DeleteServerButton.Enable = "off";

            % Update TLS row visibility and Connect button state
            updateTLSRowVisibility(app);
            updateConnectButtonState(app);
        end

        function updateTLSRowVisibility(app)
            % Update visibility of TLS configuration rows
            % Rows 5-7 contain: Key, Certificate, and Trusted Certificate fields

            if app.EnableTLSCheckBox.Value
                % Show TLS configuration fields
                app.ConfigurationGridLayout.RowHeight(5:7) = {'fit', 'fit', 'fit'};
            else
                % Hide TLS configuration fields by setting height to 0
                app.ConfigurationGridLayout.RowHeight(5:7) = {0, 0, 0};
            end
        end

        function uniqueName = generateUniqueServerName(app)
            % Generate a unique server name for new PACS configurations
            % Ensures the name doesn't conflict with existing saved servers

            if isempty(app.SavedServerConfigs)
                existingNames = string.empty();
            else
                existingNames = [app.SavedServerConfigs.ServerName];
            end

            % Use MATLAB's built-in function to create unique name
            uniqueName = matlab.lang.makeUniqueStrings(app.ServerNameDefault, existingNames);
        end

        function filename = selectTLSFile(~, dialogTitle, fileTypeLabel)
            % Helper function to open file selection dialog for TLS files
            % All TLS files use .pem format
            %
            % Inputs:
            %   dialogTitle - Title for the file selection dialog
            %   fileTypeLabel - Label for the file type filter
            %
            % Output:
            %   filename - Full path to selected file, or empty string if cancelled

            [file, path] = uigetfile(["*.pem", fileTypeLabel], dialogTitle);

            if isequal(file, 0)
                % User cancelled the dialog
                filename = '';
                return;
            end

            filename = fullfile(path, file);
        end

        function updateServerDropdownList(app, currentServerName)
            % Update the server selection dropdown with current server list
            % and select the specified server
            %
            % Input:
            %   currentServerName - Name of server to select in dropdown

            app.ServerSelectionDropDown.Items = getServerNameList(app);
            app.ServerSelectionDropDown.Value = currentServerName;
            app.DeleteServerButton.Enable = "on";
        end

        function updateConnectionStatus(app, isConnected)
            % Update UI to reflect current connection status
            %
            % Input:
            %   isConnected - true if connection successful, false otherwise

            if isConnected
                % Connection successful
                app.ConnectionStatusIcon.Visible = "on";
                app.ConnectButton.Text = "Disconnect";
                app.IsCurrentlyConnected = true;

                % If connected, show Query/Retrieve tab
                app.TabGroup.SelectedTab = app.QueryRetrieveTab;
            else
                % Connection failed
                app.ConnectionStatusIcon.Visible = "off";
                app.ConnectButton.Text = "Connect";
                app.IsCurrentlyConnected = false;

                msg = "Unable to connect to PACS server '" + string(app.ServerNameEditField.Value) + ...
                    "' at " + string(app.HostIPAddressEditField.Value) + ":" + num2str(app.PortNumberEditField.Value) + newline + newline + ...
                    "Please verify:" + newline + ...
                    "- Server is running and accessible" + newline + ...
                    "- IP address and port are correct" + newline + ...
                    "- AE Titles match server configuration";
                uialert(app.MainFigure, msg, "Connection Failed");

            end
        end

        function updateConnectButtonState(app)
            % UPDATECONNECTBUTTONSTATE Enable or disable Connect button
            % based on whether all required connection fields are filled.
            % Required: IP Address, Port, Client AE Title, Server AE Title.
            % If TLS is enabled: Key, Certificate, and Trusted Certificate
            % must also be non-empty.

            % Check required fields
            hasIPAddress = ~isempty(strtrim(app.HostIPAddressEditField.Value));
            hasPort = app.PortNumberEditField.Value > 0;
            hasClientAETitle = ~isempty(strtrim(app.ClientAETitleEditField.Value));
            hasServerAETitle = ~isempty(strtrim(app.ServerAETitleEditField.Value));

            isValid = hasIPAddress && hasPort && hasClientAETitle && hasServerAETitle;

            % If TLS is enabled, also require certificate fields
            if isValid && app.EnableTLSCheckBox.Value
                hasKey = ~isempty(strtrim(app.TLSKeyFileEditField.Value));
                hasCert = ~isempty(strtrim(app.TLSCertificateEditField.Value));
                hasTrustedCert = ~isempty(strtrim(app.TLSTrustedCertEditField.Value));
                isValid = hasKey && hasCert && hasTrustedCert;
            end

            if isValid
                app.ConnectButton.Enable = "on";
            else
                app.ConnectButton.Enable = "off";
            end
        end

        function addRowToQueryTable(app, fieldName)
            % Add a new row to the query parameters table
            %
            % Input:
            %   fieldName - DICOM field name (can be empty for custom entry)

            existingData = get(app.QueryParametersTable, "Data");

            % Create new row: [Field, Value]
            newRow = {fieldName, ''};

            % Append to existing table data
            app.QueryParametersTable.Data = [existingData; newRow];
        end

        function queryParams = buildQueryParameters(app)
            % Build query parameters structure from UI inputs
            % Returns empty if validation fails
            %
            % Output:
            %   queryParams - Structure with DICOM field/value pairs, or empty

            queryParams = struct();
            tableData = app.QueryParametersTable.Data;

            % Validate and build query parameters from table
            for i = 1:size(tableData, 1)
                fieldName = tableData{i, 1};
                fieldValue = tableData{i, 2};

                % Both field and value must be non-empty
                if isempty(fieldName) || isempty(fieldValue)
                    uialert(app.MainFigure, ...
                        "All query parameters must have both a DICOM field name and a search value", "Invalid Query Parameters");
                    queryParams = [];
                    return;
                end

                % NOTE: Using dynamic field names (s.(fname)) to build
                % DICOM queries from user-selected attributes.
                queryParams.(fieldName) = fieldValue;
            end

            % Add date range if custom range is selected
            if isequal(app.DateRangeDropDown.Value, "Custom Range")
                if isempty(app.StartDatePicker.Value) || isempty(app.EndDatePicker.Value)
                    uialert(app.MainFigure, ...
                        "Custom date range requires both start and end dates", ...
                        "Missing Date Range");
                    queryParams = [];
                    return;
                end

                % Format dates as DICOM date strings (yyyyMMdd)
                startDate = string(app.StartDatePicker.Value, "yyyyMMdd");
                endDate = string(app.EndDatePicker.Value, "yyyyMMdd");

                % Add date range to query (DICOM format: startDate-endDate)
                queryParams.StudyDate = startDate + "-" + endDate;
            end
        end

        function queryResults = performDicomQuery(app, queryParams)
            % Perform DICOM query on PACS server
            %
            % Input:
            %   queryParams - Structure with query field/value pairs
            %
            % Output:
            %   queryResults - Array of structures with DICOM metadata

            if isempty(fieldnames(queryParams))
                % No query parameters - retrieve all series with specified fields
                queryResults = dicomquery(app.ActiveDicomConnection, ...
                    "series", app.DicomFieldsToRetrieve);
            else
                % Execute query
                queryResults = dicomquery(app.ActiveDicomConnection, ...
                    "series", queryParams, app.DicomFieldsToRetrieve);
            end
        end

        function populateResultsTable(app, queryResults)
            % Populate the results table with query results
            %
            % Input:
            %   queryResults - Array of structures with DICOM metadata

            tableData = [];

            for i = 1:length(queryResults)
                % Handle PatientName field (may be a structure)
                if isfield(queryResults(i), "PatientName") && ...
                        isstruct(queryResults(i).PatientName)
                    queryResults(i).PatientName = queryResults(i).PatientName.FamilyName;
                end

                % Extract values for each field to retrieve
                vals = strings(1, numel(app.DicomFieldsToRetrieve));
                for k = 1:numel(app.DicomFieldsToRetrieve)
                    % NOTE: Using dynamic field names (s.(fname)) to build
                    % DICOM queries from user-selected attributes.
                    f = app.DicomFieldsToRetrieve(k);
                    val = string(queryResults(i).(f));
                    if isempty(val)
                        vals(k) = "";
                    else
                        vals(k) = val;
                    end
                end
                rowData = vals;

                tableData = [tableData; rowData];
            end

            app.QueryResultsTable.Data = tableData;
        end

        function success = downloadSelectedSeries(app, showSuccessMessage)
            % Download method used by Import and Download workflows.

            success = false;

            % Reset filepath property
            app.Filepath = [];

            if isempty(app.ActiveDicomConnection) || ...
                    ~isa(app.ActiveDicomConnection, "dicomConnection") || ...
                    ~testConnection(app.ActiveDicomConnection)
                uialert(app.MainFigure, ...
                    "Connection to PACS server has been lost." + newline + newline + ...
                    "You will be redirected to the Configuration tab to re-establish the connection.", ...
                    "Connection Lost", "Icon", "error");
                app.TabGroup.SelectedTab = app.ConfigurationTab;
                onConnectionParameterChanged(app);
                return;
            end

            % Get SeriesInstanceUID from selected row
            seriesUIDColumnIndex = ismember(app.QueryResultsTable.ColumnName, "SeriesInstanceUID");
            selectedRowData = app.QueryResultsTable.Data(app.QueryResultsTable.Selection, :);
            seriesInstanceUID = selectedRowData(seriesUIDColumnIndex);

            % Determine progress message based on operation type
            if showSuccessMessage
                progressMsg = "Downloading DICOM data from PACS...";
            else
                progressMsg = "Importing DICOM data from PACS...";
            end

            % Show progress dialog
            progressDialog = uiprogressdlg(app.MainFigure, ...
                "Message", progressMsg, ...
                "Indeterminate", "on");

            try
                % Download DICOM files from PACS
                downloadedFiles = dicomget(app.ActiveDicomConnection, ...
                    "series", seriesInstanceUID, ...
                    "StorageDirectory", app.StorageDirEditField.Value);
            catch ME
                uialert(app.MainFigure, ME.message, "Error");
                close(progressDialog);
                return;
            end

            close(progressDialog);

            % Get download directory path
            fileInfo = dir(downloadedFiles{1}{1});
            app.Filepath = fileInfo.folder;
            success = true;

            if showSuccessMessage
                % Show success message with download location
                uialert(app.MainFigure, ...
                    "Successfully downloaded dicom files to path: "+string(fileInfo.folder), ...
                    "Download Successful", "Icon", "success");
            end
        end
    end

    % =====================================================================
    % CONFIGURATION PERSISTENCE METHODS
    % =====================================================================
    methods (Access = private)

        function saveConfigurationToPersistentStorage(app)
            % Save all configuration data to persistent storage
            % Uses static methods to maintain data across app instances

            config = struct();
            config.ServerDetails = app.SavedServerConfigs;
            config.CurrentServerName = app.ServerSelectionDropDown.Value;
            config.IsConnected = app.IsCurrentlyConnected;
            config.StorageDir = app.StorageDirEditField.Value;

            % Save to persistent variable
            PACSConnectionApp.setPersistentConfig(config);
        end

        function loadSavedConfiguration(app)
            % Load previously saved configuration from persistent storage

            config = PACSConnectionApp.getPersistentConfig();

            if ~isempty(config)
                % Restore server configurations
                if isfield(config, "ServerDetails") && ~isempty(config.ServerDetails)
                    app.SavedServerConfigs = config.ServerDetails;
                end

                % Restore last selected server
                if isfield(config, "CurrentServerName")  && ~isempty(config.CurrentServerName)
                    app.CurrentServerName = string(config.CurrentServerName);
                end

                % Restore connection state
                if ~isempty(app.SavedServerConfigs) && isfield(config, "IsConnected") 
                    app.IsCurrentlyConnected = config.IsConnected;
                end

                % Restore storage directory 
                if isfield(config, "StorageDir") && ~isempty(config.StorageDir)
                    app.StorageDirectory = config.StorageDir;
                end
            end
        end

        function restoreUIStateFromConfig(app)
            % Restore UI state from loaded configuration
            % Called after UI components are created

            % Restore storage directory
            app.StorageDirEditField.Value = app.StorageDirectory;

            if isempty(app.SavedServerConfigs)
                return;
            end

            % Update server dropdown with saved servers
            app.ServerSelectionDropDown.Items = getServerNameList(app);

            % Find and select the last used server
            serverIndex = find(ismember([app.SavedServerConfigs.ServerName], app.CurrentServerName));

            if ~isempty(serverIndex)
                % Restore last used server configuration
                serverConfig = app.SavedServerConfigs(serverIndex);
                populateConfigurationFields(app, serverConfig);

                % Reconnect if previously connected
                if app.IsCurrentlyConnected
                    togglePACSConnection(app);
                end
            else
                % No matching server found - reset to new server state
                resetConfigurationFields(app);
            end
        end
    end

    % =====================================================================
    % STATIC PERSISTENCE METHODS
    % =====================================================================
    methods (Static, Access = private)
        function config = getPersistentConfig()
            % Retrieve persistent configuration
            %
            % Output:
            %   config - Saved configuration structure

            config = PACSConfigManager.managePersistentConfig("get");
        end

        function setPersistentConfig(config)
            % Save configuration to persistent storage
            %
            % Input:
            %   config - Configuration structure to save

            PACSConfigManager.managePersistentConfig("set", config);
        end
    end

    % =====================================================================
    % DEPENDENT PROPERTY ACCESSORS
    % =====================================================================
    methods
        function set.Visible(app,value)
            % Set visibility of the dialog window
            app.MainFigure.Visible = value;
        end

        function value = get.Visible(app)
            % Get visibility of the dialog window
            value = app.MainFigure.Visible;
        end

    end


    % Callbacks that handle component events
    methods

        % Code that executes after component creation
        function startupFcn(app, OpenedFromApp)
            if nargin > 1
                app.OpenedFromApp = OpenedFromApp;
            end
            % Load previously saved configuration
            loadSavedConfiguration(app);

            % Initialize UI components
            app.ServerSelectionDropDown.Items = getServerNameList(app);
            app.ClientAETitleEditField.Value = app.ClientAETitleDefault;
            app.ServerNameEditField.Value = generateUniqueServerName(app);
            app.ServerAETitleEditField.Value = app.ServerAETitleDefault;
            app.CommonFieldsDropDown.Items = app.CommonDicomFieldNames;
            app.QueryResultsTable.ColumnName = app.DicomFieldsToRetrieve;

            % If already connected, show Query/Retrieve tab by default
            if app.IsCurrentlyConnected
                app.TabGroup.SelectedTab = app.QueryRetrieveTab;
            end

            % Restore UI state from saved configuration
            restoreUIStateFromConfig(app);

            % Configure visibility based on how dialog was opened
            if app.OpenedFromApp
                % Opened from another app - start hidden, show Import button
                app.DownloadOrImportButton.Tooltip = {'Import the data to volume viewer'};
                app.DownloadOrImportButton.Text = 'Import';
                app.MainFigure.Visible = "off";
            else
                % Standalone mode - show immediately, hide download button
                app.DownloadOrImportButton.Tooltip = {'Download the data to storage directory'};
                app.DownloadOrImportButton.Text = 'Download';
                app.MainFigure.Visible = "on";
            end
        end

        % Close request function: MainFigure
        function onCloseRequest(app, event)
            % Handle window close request (when user clicks X button)
            % Behavior depends on whether dialog was opened from another app

            if app.OpenedFromApp
                % Hide instead of close when opened from another app
                % This allows the parent app to reuse the dialog
                app.MainFigure.Visible = "off";
            else
                % Save configuration
                saveConfigurationToPersistentStorage(app);
                
                % Standalone mode - delete the app
                delete(app);
            end
        end

        % Value changed function: ServerSelectionDropDown
        function onServerSelectionChanged(app, event)
            % Handle server selection change in dropdown

            selectedServer = app.ServerSelectionDropDown.Value;

            % Check if selected server exists in saved configurations
            serverIndex = find(ismember([app.SavedServerConfigs.ServerName], selectedServer));

            if ~isempty(serverIndex)
                % Load existing server configuration
                serverConfig = app.SavedServerConfigs(serverIndex);
                populateConfigurationFields(app, serverConfig);
                onConnectionParameterChanged(app);

            elseif isequal(selectedServer, app.NewServerPlaceholder)
                % Reset to default values for new server
                resetConfigurationFields(app);
                onConnectionParameterChanged(app);
            end

        end

        % Value changed function: ClientAETitleEditField, 
        % ...and 6 other components
        function onConnectionParameterChanged(app, event)
            % Handle changes to any connection parameter
            % When connection settings are modified, reset the connection state
            % and require the user to reconnect to apply changes

            app.ConnectButton.Text = "Connect";
            app.ActiveDicomConnection = [];
            app.ConnectionStatusIcon.Visible = "off";
            app.IsCurrentlyConnected = false;
            
            % Clear previous results
            app.QueryResultsTable.Data = [];
            app.DownloadOrImportButton.Enable = "off";

            % Update Connect button enabled state based on field validity
            updateConnectButtonState(app);
        end

        % Button pushed function: SaveServerButton
        function saveCurrentServerConfiguration(app, event)
            % Save the current PACS server configuration to persistent storage
            % Updates existing configuration or adds new one

            % Validate that server name is provided
            if isempty(app.ServerNameEditField.Value)
                uialert(app.MainFigure, "Server name must not be empty", "Missing Server Name");
                return;
            end

            % Create server configuration structure
            serverConfig = struct(...
                "IPAddress", '', ...
                "Port", [], ...
                "MyAEtitle", '', ...
                "PACSAEtitle", '', ...
                "ServerName", '', ...
                "EnableTLS", false, ...
                "Key", '', ...
                "Certificate", '', ...
                "TrustedCertificate", '');

            % Populate structure with current UI values
            serverConfig.IPAddress = app.HostIPAddressEditField.Value;
            serverConfig.Port = app.PortNumberEditField.Value;
            serverConfig.MyAEtitle = app.ClientAETitleEditField.Value;
            serverConfig.PACSAEtitle = app.ServerAETitleEditField.Value;
            serverConfig.ServerName = string(app.ServerNameEditField.Value);
            serverConfig.EnableTLS = app.EnableTLSCheckBox.Value;
            serverConfig.Key = app.TLSKeyFileEditField.Value;
            serverConfig.Certificate = app.TLSCertificateEditField.Value;
            serverConfig.TrustedCertificate = app.TLSTrustedCertEditField.Value;

            if isempty(app.SavedServerConfigs)
                % First server configuration
                app.SavedServerConfigs = serverConfig;
            else
                % Check if server name already exists
                isExistingServer = ismember([app.SavedServerConfigs.ServerName], serverConfig.ServerName);

                if any(isExistingServer)
                    % Update existing server configuration
                    app.SavedServerConfigs(isExistingServer) = serverConfig;
                else
                    % Add new server configuration
                    app.SavedServerConfigs(end+1) = serverConfig;
                end
            end

            % Update the server selection dropdown
            updateServerDropdownList(app, serverConfig.ServerName);
        end

        % Button pushed function: DeleteServerButton
        function deleteCurrentServerConfiguration(app, event)
            % Delete the currently selected PACS server configuration
            % Shows confirmation dialog before deletion

            serverIndex = find(ismember([app.SavedServerConfigs.ServerName], app.ServerSelectionDropDown.Value));

            if ~isempty(serverIndex)
                % Show confirmation dialog
                serverName = app.SavedServerConfigs(serverIndex).ServerName;
                msg = "Are you sure you want to delete the PACS server configuration "+...
                    string(serverName)+"?"+newline+newline+....
                    "This action cannot be undone. You will need to re-enter all connection details if you want to use this server again.";
                selection = uiconfirm(app.MainFigure, ...
                    msg, ...
                    "Confirm Delete", ...
                    "Icon", "warning", ...
                    "Options", ["Delete", "Cancel"], ...
                    "DefaultOption", "Cancel");

                if strcmpi(selection, "Delete")
                    % Validate index is still within bounds before deletion                                                                                       
                    if serverIndex > numel(app.SavedServerConfigs)
                        return;
                    end
                    % Remove server from saved configurations
                    app.SavedServerConfigs(serverIndex) = [];

                    % Reset UI to default state
                    resetConfigurationFields(app);
                    onConnectionParameterChanged(app);
                    % Update dropdown
                    app.ServerSelectionDropDown.Items = getServerNameList(app);
                end
            end
        end

        % Button pushed function: ConnectButton
        function togglePACSConnection(app, event)
            % Connect to or disconnect from the PACS server
            % Button toggles between "Connect" and "Disconnect" states

            if isequal(app.ConnectButton.Text, "Disconnect")
                % User wants to disconnect
                onConnectionParameterChanged(app);
                return;
            end

            % Clear previous results
            app.QueryResultsTable.Data = [];
            app.DownloadOrImportButton.Enable = "off";
            
            try
                isTLSEnabled = app.EnableTLSCheckBox.Value;

                if ~isTLSEnabled
                    % Connect without TLS (insecure connection)
                    w = warning("off", "medical:dicomConnection:InsecureTransmission");
                    oc = onCleanup(@() warning(w));
                    app.ActiveDicomConnection = dicomConnection(...
                        app.HostIPAddressEditField.Value, ...
                        app.PortNumberEditField.Value, ...
                        "AETitle", app.ClientAETitleEditField.Value, ...
                        "RetrieveAETitle", app.ServerAETitleEditField.Value, ...
                        "EnableTLS", false);

                    % Show security warning on first connection
                    if ~app.IsCurrentlyConnected
                        uialert(app.MainFigure, ...
                            "Using non-TLS communication is highly insecure. Switch to TLS connection to enhance safety of medical data.", ...
                            "Warning", ...
                            "Icon", "warning");
                    end
                else
                    % Connect with TLS (secure connection)
                    app.ActiveDicomConnection = dicomConnection(...
                        app.HostIPAddressEditField.Value, ...
                        app.PortNumberEditField.Value, ...
                        app.TLSKeyFileEditField.Value, ...
                        app.TLSCertificateEditField.Value, ...
                        app.TLSTrustedCertEditField.Value, ...
                        "AETitle", app.ClientAETitleEditField.Value, ...
                        "RetrieveAETitle", app.ServerAETitleEditField.Value);
                end

                % Test the connection and update UI accordingly
                connectionSuccessful = testConnection(app.ActiveDicomConnection);
                updateConnectionStatus(app, connectionSuccessful);

            catch ME
                % Connection failed
                updateConnectionStatus(app, false);
            end
        end

        % Value changed function: EnableTLSCheckBox
        function onTLSEnabledChanged(app, event)
            % Handle changes to the TLS (Transport Layer Security) checkbox
            % Show or hide TLS certificate fields based on checkbox state

            updateTLSRowVisibility(app);
            updateConnectButtonState(app);
        end

        % Button pushed function: TLSKeyBrowseButton
        function browseTLSKeyFile(app, event)
            % Open file browser to select TLS key file (.pem format)

            filename = selectTLSFile(app, "Select Key", "Key Files");

            if isempty(filename)
                return;
            end

            app.TLSKeyFileEditField.Value = filename;
            onConnectionParameterChanged(app);  % Require reconnection
        end

        % Button pushed function: TLSCertBrowseButton
        function browseTLSCertificateFile(app, event)
            % Open file browser to select TLS certificate file (.pem format)

            filename = selectTLSFile(app, "Select Certificate", "Certificate Files");

            if isempty(filename)
                return;
            end

            app.TLSCertificateEditField.Value = filename;
            onConnectionParameterChanged(app);  % Require reconnection
        end

        % Button pushed function: TLSTrustedCertBrowseBtn
        function browseTLSTrustedCertFile(app, event)
            % Open file browser to select TLS trusted certificate file (.pem format)

            filename = selectTLSFile(app, "Select Trusted Certificate", "Certificate Files");

            if isempty(filename)
                return;
            end

            app.TLSTrustedCertEditField.Value = filename;
            onConnectionParameterChanged(app);  % Require reconnection
        end

        % Value changed function: DateRangeDropDown
        function onDateRangeSelectionChanged(app, event)
            % Handle changes to the date range selection dropdown
            % Enable/disable date pickers based on selection

            if isequal(app.DateRangeDropDown.Value, "Custom Range")
                % Enable date pickers for custom range
                app.StartDatePicker.Enable = "on";
                app.EndDatePicker.Enable = "on";
            else
                % Disable date pickers for "All Dates"
                app.StartDatePicker.Enable = "off";
                app.EndDatePicker.Enable = "off";
            end
        end

        % Value changed function: CommonFieldsDropDown
        function onCommonFieldSelected(app, event)
            % Handle selection from common DICOM fields dropdown
            % If "Other Field" is selected, add empty row for custom field

            if isequal(app.CommonFieldsDropDown.Value, "Other Field")
                addRowToQueryTable(app, '');
            end
        end

        % Button pushed function: AddFieldButton
        function addFieldToQueryTable(app, event)
            % Add selected field to the query parameters table
            % Creates new row with field name and empty value

            if isequal(app.CommonFieldsDropDown.Value, "Other Field")
                % Add empty row for custom field entry
                addRowToQueryTable(app, '');
            else
                % Add row with selected common field
                addRowToQueryTable(app, app.CommonFieldsDropDown.Value);
            end
        end

        % Button pushed function: ClearTableButton
        function clearQueryParametersTable(app, event)
            % Clear all rows from the query parameters table

            app.QueryParametersTable.Data = [];
        end

        % Selection changed function: QueryResultsTable
        function onQueryResultSelected(app, event)
            % Handle selection change in query results table
            % Enable/disable download button based on selection

            if ~isempty(app.QueryResultsTable.Selection)
                app.DownloadOrImportButton.Enable = "on";
            else
                app.DownloadOrImportButton.Enable = "off";
            end
        end

        % Button pushed function: StorageDirBrowseButton
        function browseStorageDirectory(app, event)
            % Open folder browser to select storage directory for downloads

            selectedFolder = uigetdir(app.StorageDirectory, ...
                "Select Storage Directory");

            if selectedFolder ~= 0
                app.StorageDirEditField.Value = selectedFolder;
                app.StorageDirectory = selectedFolder;
            end
        end

        % Button pushed function: RunQueryButton
        function executeQueryOnPACS(app, event)
            % Execute DICOM query on the PACS server
            % Retrieves study/series information based on query parameters

            % Verify connection is active
            if isempty(app.ActiveDicomConnection) || ...
                    ~isa(app.ActiveDicomConnection, "dicomConnection") || ...
                    ~testConnection(app.ActiveDicomConnection)
                uialert(app.MainFigure, ...
                    "Connection to PACS server has been lost." + newline + newline + ...
                    "You will be redirected to the Configuration tab to re-establish the connection.", ...
                    "Connection Lost", "Icon", "error");
                app.TabGroup.SelectedTab = app.ConfigurationTab;
                onConnectionParameterChanged(app);
                return;
            end

            % Clear previous results
            app.QueryResultsTable.Data = [];
            app.DownloadOrImportButton.Enable = "off";

            % Build query parameters from table
            queryParams = buildQueryParameters(app);
            if isempty(queryParams)
                return;  % Validation failed
            end

            try
                % Execute DICOM query
                queryResults = performDicomQuery(app, queryParams);
            catch ME
                uialert(app.MainFigure, ME.message, "Error");
                return;
            end

            % Populate results table
            populateResultsTable(app, queryResults);
        end

        % Menu selected function: DeleteFieldMenu
        function deleteQueryParameterRow(app, event)
            % Delete a specific row from the query parameters table
            % Called from context menu
            %
            % Input:
            %   event - Event data containing row information

            rowToDelete = event.InteractionInformation.DisplayRow;
            app.QueryParametersTable.Data(rowToDelete, :) = [];
        end

        % Button pushed function: DownloadOrImportButton
        function downloadOrImportSelectedData(app, event)
            if isempty(app.StorageDirEditField.Value)
                uialert(app.MainFigure,"Storage directory must not be empty","Invalid Storage Directory");
                return;
            end
            
            % Download or import selected DICOM data
            if app.OpenedFromApp
                % Import selected DICOM data from PACS to volume viewer
                % Downloads data and fires ImportIsSuccessful event for parent app to handle

                % Perform download without showing success message
                if downloadSelectedSeries(app, false)
                    % Notify listeners that import is complete
                    % Listeners can access app.Filepath to get the download location
                    notify(app, "ImportIsSuccessful");
                end
            else
                % Download selected DICOM data from PACS to local storage

                % Perform download with success message
                downloadSelectedSeries(app, true);
            end
        end
    end

    % App creation
    methods (Access = public)

        % Construct app
        function app = PACSConnectionApp(varargin)
            app = app@matlab.apps.App(varargin{:});

            if nargout == 0
                clear app
            end
        end
    end
end