classdef SegmentasiCitraApp < matlab.apps.AppBase
    % GUI Segmentasi Citra - Tugas 3 IF4073.
    % Jalankan dari root repositori: SegmentasiCitraApp

    properties (Access = public)
        UIFigure; TabGroup; SemanticTab; EdgeTab; SplitMergeTab
        InputFileField; PythonField; WeightsField; TTACheckBox
        AlphaSlider; AlphaValueLabel; DeviceDropDown
        RunButton; SaveButton; OpenOutputButton; StatusLabel
        AxesInput; AxesMask; AxesOverlay
    end

    properties (Access = private)
        RootDir = ''; InferenceScript = ''; LastResult = []
        LastOutputDir = ''; LastPythonModulePath = ''
    end

    methods (Access = public)
        function app = SegmentasiCitraApp(varargin)
            requestedVisible = 'on';
            if mod(numel(varargin), 2) ~= 0
                error('SegmentasiCitraApp:InvalidArguments', ...
                    'Argumen harus berupa pasangan nama-nilai.');
            end
            for k = 1:2:numel(varargin)
                name = char(varargin{k});
                if ~strcmpi(name, 'Visible')
                    error('SegmentasiCitraApp:UnknownArgument', ...
                        'Argumen tidak dikenal: %s', name);
                end
                requestedVisible = char(varargin{k + 1});
            end
            if ~any(strcmpi(requestedVisible, {'on', 'off'}))
                error('SegmentasiCitraApp:InvalidVisible', ...
                    'Nilai Visible harus ''on'' atau ''off''.');
            end
            appFile = which('SegmentasiCitraApp');
            if isempty(appFile), appFile = mfilename('fullpath'); end
            app.RootDir = fileparts(appFile);
            app.InferenceScript = fullfile(app.RootDir, 'model', 'predict_semantic.py');
            buildUI(app); registerApp(app, app.UIFigure);
            app.UIFigure.Visible = requestedVisible;
            if nargout == 0, clear app; end
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure), delete(app.UIFigure); end
        end
    end

    methods (Access = private)
        function buildUI(app)
            app.UIFigure = uifigure('Visible', 'off', 'Name', ...
                'Segmentasi Citra - Tugas 3 IF4073', 'Color', [0.96 0.97 0.99]);
            ss = get(groot, 'ScreenSize');
            w = min(1400, max(1000, ss(3) - 80)); h = min(900, max(680, ss(4) - 100));
            app.UIFigure.Position = [ss(1)+(ss(3)-w)/2, ss(2)+(ss(4)-h)/2, w, h];
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @closeApp, true);
            mainGrid = uigridlayout(app.UIFigure, [2 1]);
            mainGrid.RowHeight = {48, '1x'}; mainGrid.Padding = [14 10 14 12];
            mainGrid.RowSpacing = 8; mainGrid.BackgroundColor = app.UIFigure.Color;
            headerGrid = uigridlayout(mainGrid, [2 1]);
            headerGrid.Layout.Row = 1; headerGrid.RowHeight = {26, 18};
            headerGrid.Padding = [0 0 0 0]; headerGrid.RowSpacing = 0;
            headerGrid.BackgroundColor = app.UIFigure.Color;
            title = uilabel(headerGrid, 'Text', 'Segmentasi Citra - Tugas 3 IF4073', ...
                'FontSize', 20, 'FontWeight', 'bold', 'FontColor', [0.15 0.20 0.28]);
            title.Layout.Row = 1;
            subtitle = uilabel(headerGrid, 'Text', ['GUI MATLAB  |  Bagian D: ' ...
                'Semantic Segmentation (DeepLabV3+)  |  Bagian B/C: ' ...
                'belum diimplementasikan'], 'FontSize', 11, ...
                'FontColor', [0.38 0.42 0.48]);
            subtitle.Layout.Row = 2;
            app.TabGroup = uitabgroup(mainGrid); app.TabGroup.Layout.Row = 2;
            app.SemanticTab = uitab(app.TabGroup, 'Title', 'D - Semantic Segmentation');
            app.EdgeTab = uitab(app.TabGroup, 'Title', 'B - Deteksi Tepi (belum)');
            app.SplitMergeTab = uitab(app.TabGroup, 'Title', 'C - Split and Merge (belum)');
            app.TabGroup.SelectedTab = app.SemanticTab;
            buildSemanticTab(app);
            buildPlaceholderTab(app, app.EdgeTab, 'Bagian B - Deteksi Tepi', { ...
                'BELUM DIIMPLEMENTASIKAN PADA VERSI INI', '', ...
                'Sesuai pembagian tugas kelompok, implementasi operator tepi manual ' ...
                '(Laplace, LoG, Sobel, Prewitt, Roberts), Canny, dan segmentasi objek ' ...
                'berbasis tepi menjadi tanggung jawab Bagian B.', '', ...
                'Tab ini sengaja tidak memiliki tombol atau algoritma apa pun. ' ...
                'Versi ini hanya mengintegrasikan model Bagian D.'});
            buildPlaceholderTab(app, app.SplitMergeTab, 'Bagian C - Split and Merge', { ...
                'BELUM DIIMPLEMENTASIKAN PADA VERSI INI', '', ...
                'Sesuai pembagian tugas kelompok, segmentasi klasik divide-and-conquer ' ...
                '(quadtree split lalu merge region homogen) dan pengaturan threshold-nya ' ...
                'menjadi tanggung jawab Bagian C.', '', ...
                'Tab ini sengaja tidak memiliki tombol atau algoritma apa pun. ' ...
                'Versi ini hanya mengintegrasikan model Bagian D.'});
            if ispc
                defaultPython = 'python';
                venvPython = fullfile(app.RootDir, '.venv', 'Scripts', 'python.exe');
            else
                defaultPython = 'python3';
                venvPython = fullfile(app.RootDir, '.venv', 'bin', 'python3.12');
                if ~isfile(venvPython)
                    venvPython = fullfile(app.RootDir, '.venv', 'bin', 'python');
                end
            end
            if isfile(venvPython), defaultPython = venvPython; end
            envPython = getenv('SEGMENTASI_PYTHON');
            if ~isempty(envPython), defaultPython = envPython; end
            app.PythonField.Value = defaultPython;
            % Utamakan checkpoint terbaru (ResNet-101) di model/; fallback ke
            % checkpoint ResNet-50 lama di folder yang sama.
            app.WeightsField.Value = fullfile(app.RootDir, 'model', ...
                'best_deeplabv3plus_resnet101_camvid_v3.pth');
            if ~isfile(app.WeightsField.Value)
                app.WeightsField.Value = fullfile(app.RootDir, 'model', ...
                    'best_deeplabv3plus_resnet50_camvid.pth');
            end
            if isfile(app.WeightsField.Value) && isfile(app.InferenceScript)
                setStatus(app, ['Siap. Pilih citra, lalu klik "Jalankan Inferensi". ' ...
                    'Python dimuat in-process saat inferensi.'], 'info');
            else
                setStatus(app, ['Perhatian: checkpoint atau script Python tidak ' ...
                    'ditemukan. Periksa path model di panel kontrol.'], 'warn');
            end
        end

        function buildSemanticTab(app)
            grid = uigridlayout(app.SemanticTab, [1 2]);
            grid.ColumnWidth = {370, '1x'}; grid.RowHeight = {'1x'};
            grid.Padding = [8 8 8 8]; grid.ColumnSpacing = 12;
            grid.BackgroundColor = app.UIFigure.Color;
            ctrl = uipanel(grid, 'Title', 'Kontrol Inferensi', 'FontWeight', 'bold');
            ctrl.Layout.Column = 1;
            cg = uigridlayout(ctrl, [15 2]);
            cg.RowHeight = {20, 30, 20, 30, 20, 30, 20, 24, 20, 50, 28, 38, 'fit', '1x', 34};
            cg.ColumnWidth = {'1x', 88}; cg.Padding = [12 12 12 12];
            cg.RowSpacing = 5; cg.ColumnSpacing = 8;
            cg.BackgroundColor = ctrl.BackgroundColor;
            specs = { ...
                'CITRA MASUKAN', 'InputFileField', 'Pilih file citra...', ...
                'Path lengkap citra masukan (PNG/JPG/BMP/TIF).', @onBrowseImage; ...
                'PYTHON (pyenv / VENV)', 'PythonField', ...
                '.venv/bin/python3.12 atau path lengkap', ['Path lengkap Python ' ...
                'yang memiliki torch, segmentation-models-pytorch, OpenCV, dan NumPy. ' ...
                'MATLAB memuatnya in-process lewat pyenv; jika MATLAB sudah memuat ' ...
                'Python lain, restart MATLAB sebelum menjalankan inferensi.'], ...
                @onBrowsePython; ...
                'CHECKPOINT MODEL', 'WeightsField', '', ...
                'Checkpoint .pth hasil training Bagian D.', @onBrowseWeights};
            for i = 1:3
                sectionLabel(app, cg, specs{i, 1}, 2*i - 1);
                app.(specs{i, 2}) = browseRow(app, cg, 2*i, specs{i, 3}, ...
                    specs{i, 4}, specs{i, 5});
            end
            app.TTACheckBox = uicheckbox(cg, 'Text', ...
                'Test-Time Augmentation (flip horizontal)', 'Value', true, ...
                'Tooltip', ['Merata-ratakan prediksi citra asli dan citra ter-flip ' ...
                'untuk hasil yang lebih stabil.']);
            app.TTACheckBox.Layout.Row = 8; app.TTACheckBox.Layout.Column = [1 2];
            alphaLabel = uilabel(cg, 'Text', 'Alpha overlay');
            alphaLabel.Layout.Row = 9; alphaLabel.Layout.Column = 1;
            app.AlphaValueLabel = uilabel(cg, 'Text', '0.45', ...
                'HorizontalAlignment', 'right');
            app.AlphaValueLabel.Layout.Row = 9;
            app.AlphaValueLabel.Layout.Column = 2;
            app.AlphaSlider = uislider(cg, 'Limits', [0 1], 'Value', 0.45, ...
                'MajorTicks', 0:0.25:1, ...
                'MajorTickLabels', {'0', '0.25', '0.50', '0.75', '1'});
            app.AlphaSlider.Layout.Row = 10;
            app.AlphaSlider.Layout.Column = [1 2];
            app.AlphaSlider.ValueChangingFcn = createCallbackFcn(app, @onAlphaUpdate, true);
            app.AlphaSlider.ValueChangedFcn = createCallbackFcn(app, @onAlphaUpdate, true);
            deviceLabel = uilabel(cg, 'Text', 'Perangkat');
            deviceLabel.Layout.Row = 11; deviceLabel.Layout.Column = 1;
            app.DeviceDropDown = uidropdown(cg, 'Items', {'auto', 'cpu', 'cuda'}, ...
                'ItemsData', {'auto', 'cpu', 'cuda'}, 'Value', 'auto', ...
                'Tooltip', ['auto memakai CUDA bila tersedia, selain itu CPU. ' ...
                'Pilih cpu untuk memaksa inferensi CPU.']);
            app.DeviceDropDown.Layout.Row = 11;
            app.DeviceDropDown.Layout.Column = 2;
            app.RunButton = uibutton(cg, 'push', 'Text', 'Jalankan Inferensi', ...
                'ButtonPushedFcn', createCallbackFcn(app, @onRunInference, true), ...
                'FontWeight', 'bold', 'BackgroundColor', [0.11 0.42 0.75], ...
                'FontColor', [1 1 1]);
            app.RunButton.Layout.Row = 12; app.RunButton.Layout.Column = [1 2];
            app.StatusLabel = uilabel(cg, 'Text', 'Siap.', 'WordWrap', 'on', ...
                'FontSize', 11);
            app.StatusLabel.Layout.Row = 13; app.StatusLabel.Layout.Column = [1 2];
            app.SaveButton = uibutton(cg, 'push', 'Text', 'Simpan Hasil', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', createCallbackFcn(app, @onSaveResults, true));
            app.SaveButton.Layout.Row = 15; app.SaveButton.Layout.Column = 1;
            app.OpenOutputButton = uibutton(cg, 'push', 'Text', 'Buka Output', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', createCallbackFcn(app, @onOpenOutputFolder, true));
            app.OpenOutputButton.Layout.Row = 15;
            app.OpenOutputButton.Layout.Column = 2;
            viewGrid = uigridlayout(grid, [1 3]); viewGrid.Layout.Column = 2;
            viewGrid.RowHeight = {'1x'};
            viewGrid.ColumnWidth = {'1x', '1x', '1x'};
            viewGrid.Padding = [0 0 0 0];
            viewGrid.ColumnSpacing = 8; viewGrid.BackgroundColor = app.UIFigure.Color;
            app.AxesInput = imagePanel(app, viewGrid, 1, 1, 'Citra Masukan');
            app.AxesMask = imagePanel(app, viewGrid, 1, 2, 'Mask Berwarna');
            app.AxesOverlay = imagePanel(app, viewGrid, 1, 3, 'Overlay');
            showPlaceholder(app, app.AxesInput, 'Pilih citra masukan untuk memulai.');
            showPlaceholder(app, app.AxesMask, 'Mask berwarna akan tampil di sini.');
            showPlaceholder(app, app.AxesOverlay, 'Overlay akan tampil di sini.');
        end

        function buildPlaceholderTab(app, tab, titleText, bodyText)
            grid = uigridlayout(tab, [3 1]);
            grid.RowHeight = {'1x', 'fit', '1x'};
            grid.Padding = [30 24 30 24]; grid.BackgroundColor = app.UIFigure.Color;
            box = uipanel(grid, 'Title', titleText, 'FontWeight', 'bold');
            box.Layout.Row = 2;
            inner = uigridlayout(box, [1 1]); inner.Padding = [24 24 24 24];
            uilabel(inner, 'Text', bodyText, 'WordWrap', 'on', 'FontSize', 13, ...
                'FontColor', [0.30 0.34 0.40]);
        end

        function sectionLabel(~, parent, textValue, row)
            label = uilabel(parent, 'Text', textValue, 'FontWeight', 'bold', ...
                'FontSize', 11, 'FontColor', [0.25 0.33 0.47]);
            label.Layout.Row = row; label.Layout.Column = [1 2];
        end

        function field = browseRow(app, grid, row, placeholder, tooltip, callback)
            field = uieditfield(grid, 'text', 'Placeholder', placeholder, ...
                'Tooltip', tooltip);
            field.Layout.Row = row;
            button = uibutton(grid, 'push', 'Text', 'Pilih...', ...
                'ButtonPushedFcn', createCallbackFcn(app, callback, true));
            button.Layout.Row = row; button.Layout.Column = 2;
        end

        function ax = imagePanel(~, parent, row, column, panelTitle)
            panel = uipanel(parent, 'Title', panelTitle, 'FontWeight', 'bold');
            panel.Layout.Row = row; panel.Layout.Column = column;
            inner = uigridlayout(panel, [1 1]); inner.Padding = [4 4 4 4];
            ax = uiaxes(inner); ax.Box = 'off'; ax.XTick = []; ax.YTick = [];
        end

        function onBrowseImage(app, ~)
            startDir = lastFolder(app, app.InputFileField.Value);
            [file, path] = uigetfile({ ...
                '*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', ...
                'Citra (*.png, *.jpg, *.jpeg, *.bmp, *.tif, *.tiff)'; ...
                '*.*', 'Semua file'}, 'Pilih citra masukan', startDir);
            if isequal(file, 0), return; end
            fullPath = fullfile(path, file); app.InputFileField.Value = fullPath;
            try
                showImage(app, app.AxesInput, imread(fullPath), 'Citra Masukan');
                showPlaceholder(app, app.AxesMask, ...
                    'Klik "Jalankan Inferensi" untuk membuat mask.');
                showPlaceholder(app, app.AxesOverlay, ...
                    'Klik "Jalankan Inferensi" untuk membuat overlay.');
                setStatus(app, sprintf('Citra dipilih: %s', file), 'info');
            catch ME
                setStatus(app, ['Gagal membaca citra: ' ME.message], 'error');
                uialert(app.UIFigure, ME.message, 'Gagal Membaca Citra', ...
                    'Icon', 'error', 'Interpreter', 'none');
            end
        end

        function onBrowsePython(app, ~)
            if ispc, filter = {'*.exe', 'Executable (*.exe)'; '*.*', 'Semua file'};
            else, filter = {'*', 'Semua file'}; end
            startDir = lastFolder(app, app.PythonField.Value);
            [file, path] = uigetfile(filter, 'Pilih Python untuk pyenv', startDir);
            if isequal(file, 0), return; end
            app.PythonField.Value = fullfile(path, file);
            setStatus(app, ['Python diperbarui. Jika MATLAB sudah memuat Python ' ...
                'lain, restart MATLAB sebelum inferensi berikutnya.'], 'info');
        end

        function onBrowseWeights(app, ~)
            startDir = lastFolder(app, app.WeightsField.Value);
            [file, path] = uigetfile({'*.pth', 'Checkpoint PyTorch (*.pth)'; ...
                '*.*', 'Semua file'}, 'Pilih checkpoint model', startDir);
            if isequal(file, 0), return; end
            app.WeightsField.Value = fullfile(path, file);
            setStatus(app, 'Checkpoint model diperbarui.', 'info');
        end

        function onAlphaUpdate(app, event)
            app.AlphaValueLabel.Text = sprintf('%.2f', event.Value);
        end

        function onRunInference(app, ~)
            progressDialog = []; pythonExe = '';
            try
                imagePath = strtrim(app.InputFileField.Value);
                pythonValue = strtrim(app.PythonField.Value);
                weightsPath = strtrim(app.WeightsField.Value);
                validateFile(app, imagePath, 'Citra masukan');
                validateFile(app, weightsPath, 'Checkpoint model');
                validateFile(app, app.InferenceScript, 'Script predict_semantic.py');
                pythonExe = SegmentasiCitraPython.resolveExecutable(pythonValue);
                runDir = fullfile(tempdir, 'SegmentasiCitra', ...
                    ['run_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'))]);
                if ~isfolder(runDir), mkdir(runDir); end
                maskPath = fullfile(runDir, 'mask.png');
                overlayPath = fullfile(runDir, 'overlay.png');
                try showImage(app, app.AxesInput, imread(imagePath), 'Citra Masukan');
                catch; end % Pratinjau gagal tidak menghalangi inferensi.
                clearResultViews(app);
                setStatus(app, 'Menyiapkan Python in-process...', 'busy');
                app.RunButton.Enable = 'off'; app.SaveButton.Enable = 'off';
                app.OpenOutputButton.Enable = 'off'; drawnow;
                progressDialog = uiprogressdlg(app.UIFigure, ...
                    'Title', 'Inferensi DeepLabV3+', ...
                    'Message', 'Menyiapkan Python in-process...', ...
                    'Indeterminate', 'on');
                [pythonExe, pyModule, modulePath] = SegmentasiCitraPython.prepare( ...
                    pythonExe, app.InferenceScript, app.RootDir, ...
                    app.PythonField.Value);
                app.LastPythonModulePath = modulePath;
                progressDialog.Message = 'Memuat model dan memproses citra...';
                drawnow; startTime = tic;
                SegmentasiCitraPython.run(pyModule, imagePath, weightsPath, ...
                    maskPath, overlayPath, double(app.AlphaSlider.Value), ...
                    logical(app.TTACheckBox.Value), app.DeviceDropDown.Value);
                wallSeconds = toc(startTime);
                if ~isfile(maskPath) || ~isfile(overlayPath)
                    error('SegmentasiCitraApp:MissingOutput', ...
                        ['Python selesai tanpa menghasilkan mask/overlay. ' ...
                        'Pastikan model/predict_semantic.py versi terbaru digunakan.']);
                end
                showImage(app, app.AxesMask, imread(maskPath), 'Mask Berwarna');
                showImage(app, app.AxesOverlay, imread(overlayPath), 'Overlay');
                app.LastResult = struct('imagePath', imagePath, ...
                    'maskPath', maskPath, 'overlayPath', overlayPath, ...
                    'outputDir', runDir, 'pythonExe', pythonExe, ...
                    'pythonModule', app.LastPythonModulePath);
                app.LastOutputDir = runDir;
                app.SaveButton.Enable = 'on'; app.OpenOutputButton.Enable = 'on';
                setStatus(app, sprintf( ...
                    'Selesai dalam %.2f detik. Output disimpan di: %s', ...
                    wallSeconds, runDir), 'success');
            catch ME
                if ~isempty(progressDialog) && isvalid(progressDialog)
                    delete(progressDialog);
                end
                progressDialog = [];
                message = SegmentasiCitraPython.describeError(ME, pythonExe, ...
                    app.PythonField.Value, app.RootDir);
                setStatus(app, ['Gagal: ' message], 'error');
                uialert(app.UIFigure, message, 'Inferensi Gagal', ...
                    'Icon', 'error', 'Interpreter', 'none');
            end
            if ~isempty(progressDialog) && isvalid(progressDialog)
                delete(progressDialog);
            end
            app.RunButton.Enable = 'on';
        end

        function showImage(~, ax, img, titleText)
            if isempty(img), return; end
            if ismatrix(img), img = repmat(img, [1 1 3]);
            elseif size(img, 3) > 3, img = img(:, :, 1:3); end
            image(ax, img); axis(ax, 'image'); axis(ax, 'off');
            ax.YDir = 'reverse';
            title(ax, titleText, 'Interpreter', 'none');
        end

        function showPlaceholder(~, ax, message)
            cla(ax); axis(ax, 'off');
            text(ax, 0.5, 0.5, message, 'Units', 'normalized', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'Color', [0.45 0.48 0.52], 'FontSize', 11, ...
                'Interpreter', 'none');
        end

        function clearResultViews(app)
            showPlaceholder(app, app.AxesMask, 'Sedang memproses...');
            showPlaceholder(app, app.AxesOverlay, 'Sedang memproses...');
        end

        function setStatus(app, textValue, kind)
            app.StatusLabel.Text = textValue;
            switch lower(kind)
                case 'success', app.StatusLabel.FontColor = [0.05 0.45 0.15];
                case 'error', app.StatusLabel.FontColor = [0.72 0.10 0.10];
                case 'warn', app.StatusLabel.FontColor = [0.65 0.40 0.05];
                case 'busy', app.StatusLabel.FontColor = [0.35 0.30 0.05];
                otherwise, app.StatusLabel.FontColor = [0.25 0.29 0.35];
            end
            drawnow;
        end

        function onSaveResults(app, ~)
            if isempty(app.LastResult), return; end
            folder = uigetdir(app.LastResult.outputDir, ...
                'Pilih folder penyimpanan hasil');
            if isequal(folder, 0), return; end
            [~, base] = fileparts(app.LastResult.imagePath);
            stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
            files = {app.LastResult.maskPath, 'mask', 'png'; ...
                app.LastResult.overlayPath, 'overlay', 'png'};
            try
                for i = 1:size(files, 1)
                    copyfile(files{i, 1}, fullfile(folder, sprintf( ...
                        '%s_%s_%s.%s', base, files{i, 2}, stamp, files{i, 3})));
                end
                setStatus(app, sprintf('Hasil disalin ke: %s', folder), 'success');
            catch ME
                setStatus(app, ['Gagal menyimpan hasil: ' ME.message], 'error');
                uialert(app.UIFigure, ME.message, 'Gagal Menyimpan Hasil', ...
                    'Icon', 'error', 'Interpreter', 'none');
            end
        end

        function onOpenOutputFolder(app, ~)
            folder = app.LastOutputDir;
            if isempty(folder) || ~isfolder(folder)
                uialert(app.UIFigure, 'Folder output belum tersedia.', ...
                    'Buka Output', 'Icon', 'warning', 'Interpreter', 'none');
                return;
            end
            try
                if ispc
                    winopen(folder);
                else
                    if ismac, command = 'open'; else, command = 'xdg-open'; end
                    [status, ~] = system([command ' ' shellQuote(app, folder) ...
                        ' >/dev/null 2>&1 &']);
                    if status ~= 0
                        error('Perintah "%s" gagal (exit code %d).', command, status);
                    end
                end
            catch ME
                uialert(app.UIFigure, ME.message, 'Gagal Membuka Folder', ...
                    'Icon', 'warning', 'Interpreter', 'none');
            end
        end

        function validateFile(~, filePath, label)
            if isempty(filePath)
                error('SegmentasiCitraApp:MissingFile', '%s belum dipilih.', label);
            end
            if ~isfile(filePath)
                error('SegmentasiCitraApp:MissingFile', ...
                    '%s tidak ditemukan: %s', label, filePath);
            end
        end

        function folder = lastFolder(~, value)
            value = char(value);
            if ~isempty(value) && isfile(value)
                folder = fileparts(value);
            elseif ~isempty(value) && isfolder(value)
                folder = value;
            else
                folder = pwd;
            end
            if isempty(folder), folder = pwd; end
        end

        function quoted = shellQuote(~, value)
            % Quoting path agar aman untuk sh (Unix) maupun cmd.exe (Windows).
            value = char(value);
            if ispc, quoted = ['"' strrep(value, '"', '""') '"'];
            else
                quote = char(39);
                quoted = [quote strrep(value, quote, [quote '\' quote quote]) quote];
            end
        end

        function closeApp(app, ~)
            delete(app);
        end
    end
end
