classdef SegmentasiCitraApp < matlab.apps.AppBase
    %SEGMENTASICITRAAPP GUI MATLAB untuk Tugas 3 IF4073 - Segmentasi Citra.
    %
    %   Aplikasi ini mengintegrasikan model Bagian D (DeepLabV3+ ResNet-50,
    %   11 kelas CamVid) melalui antarmuka Python in-process MATLAB (pyenv /
    %   py.importlib), bukan subprocess. Bagian B (deteksi tepi) dan Bagian C
    %   (split and merge) sengaja hanya berupa placeholder dan TIDAK
    %   diimplementasikan pada versi ini.
    %
    %   Jalankan dari root repositori:
    %       SegmentasiCitraApp
    %
    %   Persentase kelas yang ditampilkan adalah CAKUPAN AREA PIKEL, bukan
    %   akurasi, karena citra masukan tidak memiliki ground-truth.

    properties (Access = public)
        UIFigure
        TabGroup
        SemanticTab
        EdgeTab
        SplitMergeTab

        InputFileField
        PythonField
        WeightsField
        TTACheckBox
        AlphaSlider
        AlphaValueLabel
        DeviceDropDown
        RunButton
        SaveButton
        OpenOutputButton
        StatusLabel

        AxesInput
        AxesMask
        AxesOverlay
        InfoTextArea
        ClassTable
    end

    properties (Access = private)
        RootDir = ''
        InferenceScript = ''
        LastResult = []
        LastOutputDir = ''
        PyModule = []
        PyModulePython = ''
        PyModuleScript = ''
        LastPythonModulePath = ''
    end

    methods (Access = public)
        function app = SegmentasiCitraApp(varargin)
            %SEGMENTASICITRAAPP Membuat dan menampilkan GUI.
            %   SegmentasiCitraApp('Visible','off') berguna untuk pengujian.

            requestedVisible = 'on';
            if mod(numel(varargin), 2) ~= 0
                error('SegmentasiCitraApp:InvalidArguments', ...
                    'Argumen harus berupa pasangan nama-nilai.');
            end
            for k = 1:2:numel(varargin)
                name = char(varargin{k});
                value = char(varargin{k + 1});
                if strcmpi(name, 'Visible')
                    requestedVisible = value;
                else
                    error('SegmentasiCitraApp:UnknownArgument', ...
                        'Argumen tidak dikenal: %s', name);
                end
            end
            if ~any(strcmpi(requestedVisible, {'on', 'off'}))
                error('SegmentasiCitraApp:InvalidVisible', ...
                    'Nilai Visible harus ''on'' atau ''off''.');
            end

            appFile = which('SegmentasiCitraApp');
            if isempty(appFile)
                appFile = mfilename('fullpath');
            end
            app.RootDir = fileparts(appFile);
            app.InferenceScript = fullfile(app.RootDir, 'model', 'predict_semantic.py');

            createComponents(app);
            registerApp(app, app.UIFigure);
            app.UIFigure.Visible = requestedVisible;

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    methods (Access = private)
        function createComponents(app)
            % Membangun seluruh komponen antarmuka secara programatik.

            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = 'Segmentasi Citra - Tugas 3 IF4073';
            app.UIFigure.Color = [0.96 0.97 0.99];
            screenSize = get(groot, 'ScreenSize');
            width = min(1400, max(1000, screenSize(3) - 80));
            height = min(900, max(680, screenSize(4) - 100));
            app.UIFigure.Position = [ ...
                screenSize(1) + (screenSize(3) - width) / 2, ...
                screenSize(2) + (screenSize(4) - height) / 2, ...
                width, height];
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @closeApp, true);

            mainGrid = uigridlayout(app.UIFigure, [2 1]);
            mainGrid.RowHeight = {48, '1x'};
            mainGrid.Padding = [14 10 14 12];
            mainGrid.RowSpacing = 8;
            mainGrid.BackgroundColor = app.UIFigure.Color;

            headerGrid = uigridlayout(mainGrid, [2 1]);
            headerGrid.Layout.Row = 1;
            headerGrid.RowHeight = {26, 18};
            headerGrid.Padding = [0 0 0 0];
            headerGrid.RowSpacing = 0;
            headerGrid.BackgroundColor = app.UIFigure.Color;

            titleLabel = uilabel(headerGrid);
            titleLabel.Text = 'Segmentasi Citra - Tugas 3 IF4073';
            titleLabel.FontSize = 20;
            titleLabel.FontWeight = 'bold';
            titleLabel.FontColor = [0.15 0.20 0.28];
            titleLabel.Layout.Row = 1;

            subtitleLabel = uilabel(headerGrid);
            subtitleLabel.Text = ['GUI MATLAB  |  Bagian D: Semantic Segmentation (DeepLabV3+ ResNet-50)  |  ' ...
                'Bagian B/C: belum diimplementasikan'];
            subtitleLabel.FontSize = 11;
            subtitleLabel.FontColor = [0.38 0.42 0.48];
            subtitleLabel.Layout.Row = 2;

            app.TabGroup = uitabgroup(mainGrid);
            app.TabGroup.Layout.Row = 2;

            app.SemanticTab = uitab(app.TabGroup, 'Title', 'D - Semantic Segmentation');
            app.EdgeTab = uitab(app.TabGroup, 'Title', 'B - Deteksi Tepi (belum)');
            app.SplitMergeTab = uitab(app.TabGroup, 'Title', 'C - Split and Merge (belum)');
            app.TabGroup.SelectedTab = app.SemanticTab;

            buildSemanticTab(app);
            buildPlaceholderTab(app, app.EdgeTab, 'Bagian B - Deteksi Tepi', { ...
                'BELUM DIIMPLEMENTASIKAN PADA VERSI INI', ...
                '', ...
                'Sesuai pembagian tugas kelompok, implementasi operator tepi manual ' ...
                '(Laplace, LoG, Sobel, Prewitt, Roberts), Canny, dan segmentasi objek ' ...
                'berbasis tepi menjadi tanggung jawab Bagian B.', ...
                '', ...
                'Tab ini sengaja tidak memiliki tombol atau algoritma apa pun. ' ...
                'Versi ini hanya mengintegrasikan model Bagian D.'});
            buildPlaceholderTab(app, app.SplitMergeTab, 'Bagian C - Split and Merge', { ...
                'BELUM DIIMPLEMENTASIKAN PADA VERSI INI', ...
                '', ...
                'Sesuai pembagian tugas kelompok, segmentasi klasik divide-and-conquer ' ...
                '(quadtree split lalu merge region homogen) dan pengaturan threshold-nya ' ...
                'menjadi tanggung jawab Bagian C.', ...
                '', ...
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
            if isfile(venvPython)
                defaultPython = venvPython;
            end
            envPython = getenv('SEGMENTASI_PYTHON');
            if ~isempty(envPython)
                defaultPython = envPython;
            end
            app.PythonField.Value = defaultPython;
            app.WeightsField.Value = fullfile(app.RootDir, 'model', ...
                'best_deeplabv3plus_resnet50_camvid.pth');

            if isfile(app.WeightsField.Value) && isfile(app.InferenceScript)
                setStatus(app, ['Siap. Pilih citra, lalu klik "Jalankan Inferensi". ' ...
                    'Python dimuat in-process saat inferensi.'], 'info');
            else
                setStatus(app, ['Perhatian: checkpoint atau script Python tidak ditemukan. ' ...
                    'Periksa path model di panel kontrol.'], 'warn');
            end
        end

        function buildSemanticTab(app)
            grid = uigridlayout(app.SemanticTab, [1 2]);
            grid.ColumnWidth = {370, '1x'};
            grid.RowHeight = {'1x'};
            grid.Padding = [8 8 8 8];
            grid.ColumnSpacing = 12;
            grid.BackgroundColor = app.UIFigure.Color;

            controlPanel = uipanel(grid, 'Title', 'Kontrol Inferensi', 'FontWeight', 'bold');
            controlPanel.Layout.Column = 1;

            cg = uigridlayout(controlPanel, [15 2]);
            cg.RowHeight = {20, 30, 20, 30, 20, 30, 20, 24, 20, 50, 28, 38, 'fit', '1x', 34};
            cg.ColumnWidth = {'1x', 88};
            cg.Padding = [12 12 12 12];
            cg.RowSpacing = 5;
            cg.ColumnSpacing = 8;
            cg.BackgroundColor = controlPanel.BackgroundColor;

            inputHeading = uilabel(cg);
            inputHeading.Text = 'CITRA MASUKAN';
            inputHeading.FontWeight = 'bold';
            inputHeading.FontSize = 11;
            inputHeading.FontColor = [0.25 0.33 0.47];
            inputHeading.Layout.Row = 1;
            inputHeading.Layout.Column = [1 2];

            app.InputFileField = uieditfield(cg, 'text');
            app.InputFileField.Layout.Row = 2;
            app.InputFileField.Placeholder = 'Pilih file citra...';
            app.InputFileField.Tooltip = 'Path lengkap citra masukan (PNG/JPG/BMP/TIF).';

            browseImageButton = uibutton(cg, 'push', 'Text', 'Pilih...', ...
                'ButtonPushedFcn', createCallbackFcn(app, @onBrowseImage, true));
            browseImageButton.Layout.Row = 2;
            browseImageButton.Layout.Column = 2;

            pythonHeading = uilabel(cg);
            pythonHeading.Text = 'PYTHON (pyenv / VENV)';
            pythonHeading.FontWeight = 'bold';
            pythonHeading.FontSize = 11;
            pythonHeading.FontColor = [0.25 0.33 0.47];
            pythonHeading.Layout.Row = 3;
            pythonHeading.Layout.Column = [1 2];

            app.PythonField = uieditfield(cg, 'text');
            app.PythonField.Layout.Row = 4;
            app.PythonField.Placeholder = '.venv/bin/python3.12 atau path lengkap';
            app.PythonField.Tooltip = ['Path lengkap Python yang memiliki torch, ' ...
                'segmentation-models-pytorch, OpenCV, dan NumPy. MATLAB memuatnya ' ...
                'in-process lewat pyenv; jika MATLAB sudah memuat Python lain, ' ...
                'restart MATLAB sebelum menjalankan inferensi.'];

            browsePythonButton = uibutton(cg, 'push', 'Text', 'Pilih...', ...
                'ButtonPushedFcn', createCallbackFcn(app, @onBrowsePython, true));
            browsePythonButton.Layout.Row = 4;
            browsePythonButton.Layout.Column = 2;

            weightsHeading = uilabel(cg);
            weightsHeading.Text = 'CHECKPOINT MODEL';
            weightsHeading.FontWeight = 'bold';
            weightsHeading.FontSize = 11;
            weightsHeading.FontColor = [0.25 0.33 0.47];
            weightsHeading.Layout.Row = 5;
            weightsHeading.Layout.Column = [1 2];

            app.WeightsField = uieditfield(cg, 'text');
            app.WeightsField.Layout.Row = 6;
            app.WeightsField.Tooltip = 'Checkpoint .pth hasil training Bagian D.';

            browseWeightsButton = uibutton(cg, 'push', 'Text', 'Pilih...', ...
                'ButtonPushedFcn', createCallbackFcn(app, @onBrowseWeights, true));
            browseWeightsButton.Layout.Row = 6;
            browseWeightsButton.Layout.Column = 2;

            settingsHeading = uilabel(cg);
            settingsHeading.Text = 'PENGATURAN INFERENSI';
            settingsHeading.FontWeight = 'bold';
            settingsHeading.FontSize = 11;
            settingsHeading.FontColor = [0.25 0.33 0.47];
            settingsHeading.Layout.Row = 7;
            settingsHeading.Layout.Column = [1 2];

            app.TTACheckBox = uicheckbox(cg, 'Text', ...
                'Test-Time Augmentation (flip horizontal)');
            app.TTACheckBox.Value = true;
            app.TTACheckBox.Layout.Row = 8;
            app.TTACheckBox.Layout.Column = [1 2];
            app.TTACheckBox.Tooltip = ['Merata-ratakan prediksi citra asli dan ' ...
                'citra ter-flip untuk hasil yang lebih stabil.'];

            alphaLabel = uilabel(cg);
            alphaLabel.Text = 'Alpha overlay';
            alphaLabel.Layout.Row = 9;
            alphaLabel.Layout.Column = 1;

            app.AlphaValueLabel = uilabel(cg);
            app.AlphaValueLabel.Text = '0.45';
            app.AlphaValueLabel.HorizontalAlignment = 'right';
            app.AlphaValueLabel.Layout.Row = 9;
            app.AlphaValueLabel.Layout.Column = 2;

            app.AlphaSlider = uislider(cg, 'Limits', [0 1], 'Value', 0.45, ...
                'MajorTicks', 0:0.25:1, 'MajorTickLabels', {'0', '0.25', '0.50', '0.75', '1'});
            app.AlphaSlider.Layout.Row = 10;
            app.AlphaSlider.Layout.Column = [1 2];
            app.AlphaSlider.ValueChangingFcn = createCallbackFcn(app, @onAlphaChanging, true);
            app.AlphaSlider.ValueChangedFcn = createCallbackFcn(app, @onAlphaChanged, true);

            deviceLabel = uilabel(cg);
            deviceLabel.Text = 'Perangkat';
            deviceLabel.Layout.Row = 11;
            deviceLabel.Layout.Column = 1;

            app.DeviceDropDown = uidropdown(cg, ...
                'Items', {'auto', 'cpu', 'cuda'}, ...
                'ItemsData', {'auto', 'cpu', 'cuda'}, ...
                'Value', 'auto');
            app.DeviceDropDown.Layout.Row = 11;
            app.DeviceDropDown.Layout.Column = 2;
            app.DeviceDropDown.Tooltip = ['auto memakai CUDA bila tersedia, ' ...
                'selain itu CPU. Pilih cpu untuk memaksa inferensi CPU.'];

            app.RunButton = uibutton(cg, 'push', 'Text', 'Jalankan Inferensi', ...
                'ButtonPushedFcn', createCallbackFcn(app, @onRunInference, true), ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.11 0.42 0.75], ...
                'FontColor', [1 1 1]);
            app.RunButton.Layout.Row = 12;
            app.RunButton.Layout.Column = [1 2];

            app.StatusLabel = uilabel(cg);
            app.StatusLabel.Text = 'Siap.';
            app.StatusLabel.WordWrap = 'on';
            app.StatusLabel.FontSize = 11;
            app.StatusLabel.Layout.Row = 13;
            app.StatusLabel.Layout.Column = [1 2];

            app.SaveButton = uibutton(cg, 'push', 'Text', 'Simpan Hasil', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', createCallbackFcn(app, @onSaveResults, true));
            app.SaveButton.Layout.Row = 15;
            app.SaveButton.Layout.Column = 1;

            app.OpenOutputButton = uibutton(cg, 'push', 'Text', 'Buka Output', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', createCallbackFcn(app, @onOpenOutputFolder, true));
            app.OpenOutputButton.Layout.Row = 15;
            app.OpenOutputButton.Layout.Column = 2;

            viewGrid = uigridlayout(grid, [2 3]);
            viewGrid.Layout.Column = 2;
            viewGrid.RowHeight = {'1.45x', '1x'};
            viewGrid.ColumnWidth = {'1x', '1x', '1x'};
            viewGrid.Padding = [0 0 0 0];
            viewGrid.RowSpacing = 8;
            viewGrid.ColumnSpacing = 8;
            viewGrid.BackgroundColor = app.UIFigure.Color;

            app.AxesInput = createImagePanel(app, viewGrid, 1, 1, 'Citra Masukan');
            app.AxesMask = createImagePanel(app, viewGrid, 1, 2, 'Mask Berwarna');
            app.AxesOverlay = createImagePanel(app, viewGrid, 1, 3, 'Overlay');

            resultsPanel = uipanel(viewGrid, 'Title', 'Analisis Hasil', 'FontWeight', 'bold');
            resultsPanel.Layout.Row = 2;
            resultsPanel.Layout.Column = [1 3];

            resultsGrid = uigridlayout(resultsPanel, [1 2]);
            resultsGrid.ColumnWidth = {'1.12x', '1x'};
            resultsGrid.Padding = [8 8 8 8];
            resultsGrid.ColumnSpacing = 8;
            resultsGrid.BackgroundColor = resultsPanel.BackgroundColor;

            summaryPanel = uipanel(resultsGrid, 'Title', 'Ringkasan & Pengaturan');
            summaryPanel.Layout.Row = 1;
            summaryPanel.Layout.Column = 1;
            summaryGrid = uigridlayout(summaryPanel, [1 1]);
            summaryGrid.Padding = [8 8 8 8];
            app.InfoTextArea = uitextarea(summaryGrid, 'Editable', 'off');
            app.InfoTextArea.FontSize = 11;
            app.InfoTextArea.Value = { ...
                'Belum ada hasil inferensi.'; ...
                ''; ...
                'Pilih citra, periksa Python/checkpoint, lalu klik "Jalankan Inferensi".'; ...
                'Python dijalankan di dalam MATLAB (pyenv), bukan sebagai subprocess.'; ...
                ''; ...
                'Persentase kelas adalah cakupan area piksel, BUKAN akurasi.'};

            coveragePanel = uipanel(resultsGrid, 'Title', 'Cakupan Area per Kelas');
            coveragePanel.Layout.Row = 1;
            coveragePanel.Layout.Column = 2;
            coverageGrid = uigridlayout(coveragePanel, [2 1]);
            coverageGrid.RowHeight = {'fit', '1x'};
            coverageGrid.Padding = [8 8 8 8];
            coverageGrid.RowSpacing = 4;

            noteLabel = uilabel(coverageGrid);
            noteLabel.Text = ['CATATAN: persentase di bawah adalah cakupan area piksel, ' ...
                'BUKAN akurasi model. Tidak ada ground-truth pada citra masukan. ' ...
                'Warna sel = warna kelas pada mask.'];
            noteLabel.WordWrap = 'on';
            noteLabel.FontSize = 11;
            noteLabel.FontWeight = 'bold';
            noteLabel.FontColor = [0.72 0.12 0.10];
            noteLabel.Layout.Row = 1;

            app.ClassTable = uitable(coverageGrid);
            app.ClassTable.ColumnName = {'Kelas', 'Warna', 'Piksel', 'Cakupan (%)'};
            app.ClassTable.ColumnWidth = {110, 50, 75, 95};
            app.ClassTable.RowName = {};
            app.ClassTable.Data = cell(0, 4);
            app.ClassTable.FontSize = 11;
            app.ClassTable.Layout.Row = 2;

            showPlaceholder(app, app.AxesInput, 'Pilih citra masukan untuk memulai.');
            showPlaceholder(app, app.AxesMask, 'Mask berwarna akan tampil di sini.');
            showPlaceholder(app, app.AxesOverlay, 'Overlay akan tampil di sini.');
        end

        function buildPlaceholderTab(app, tab, titleText, bodyText)
            % Tab B/C hanya berisi keterangan, tanpa algoritma atau callback.
            grid = uigridlayout(tab, [3 1]);
            grid.RowHeight = {'1x', 'fit', '1x'};
            grid.Padding = [30 24 30 24];
            grid.BackgroundColor = app.UIFigure.Color;

            box = uipanel(grid, 'Title', titleText, 'FontWeight', 'bold');
            box.Layout.Row = 2;
            inner = uigridlayout(box, [1 1]);
            inner.Padding = [24 24 24 24];
            label = uilabel(inner);
            label.Text = bodyText;
            label.WordWrap = 'on';
            label.FontSize = 13;
            label.FontColor = [0.30 0.34 0.40];
        end

        function ax = createImagePanel(~, parent, row, column, panelTitle)
            panel = uipanel(parent, 'Title', panelTitle, 'FontWeight', 'bold');
            panel.Layout.Row = row;
            panel.Layout.Column = column;
            inner = uigridlayout(panel, [1 1]);
            inner.Padding = [4 4 4 4];
            ax = uiaxes(inner);
            ax.Box = 'off';
            ax.XTick = [];
            ax.YTick = [];
        end

        function onBrowseImage(app, ~)
            startDir = lastFolder(app, app.InputFileField.Value);
            [file, path] = uigetfile({ ...
                '*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', ...
                'Citra (*.png, *.jpg, *.jpeg, *.bmp, *.tif, *.tiff)'; ...
                '*.*', 'Semua file'}, 'Pilih citra masukan', startDir);
            if isequal(file, 0)
                return;
            end
            fullPath = fullfile(path, file);
            app.InputFileField.Value = fullPath;
            try
                img = imread(fullPath);
                showImage(app, app.AxesInput, img, 'Citra Masukan');
                showPlaceholder(app, app.AxesMask, ...
                    'Klik "Jalankan Inferensi" untuk membuat mask.');
                showPlaceholder(app, app.AxesOverlay, ...
                    'Klik "Jalankan Inferensi" untuk membuat overlay.');
                clearAnalysis(app);
                setStatus(app, sprintf('Citra dipilih: %s', file), 'info');
            catch ME
                setStatus(app, ['Gagal membaca citra: ' ME.message], 'error');
                uialert(app.UIFigure, ME.message, 'Gagal Membaca Citra', 'Icon', 'error', 'Interpreter', 'none');
            end
        end

        function onBrowsePython(app, ~)
            if ispc
                filter = {'*.exe', 'Executable (*.exe)'; '*.*', 'Semua file'};
            else
                filter = {'*', 'Semua file'};
            end
            startDir = lastFolder(app, app.PythonField.Value);
            [file, path] = uigetfile(filter, 'Pilih Python untuk pyenv', startDir);
            if isequal(file, 0)
                return;
            end
            app.PythonField.Value = fullfile(path, file);
            app.PyModule = [];
            setStatus(app, ['Python diperbarui. Jika MATLAB sudah memuat Python lain, ' ...
                'restart MATLAB sebelum inferensi berikutnya.'], 'info');
        end

        function onBrowseWeights(app, ~)
            startDir = lastFolder(app, app.WeightsField.Value);
            [file, path] = uigetfile({'*.pth', 'Checkpoint PyTorch (*.pth)'; ...
                '*.*', 'Semua file'}, 'Pilih checkpoint model', startDir);
            if isequal(file, 0)
                return;
            end
            app.WeightsField.Value = fullfile(path, file);
            setStatus(app, 'Checkpoint model diperbarui.', 'info');
        end

        function onAlphaChanging(app, event)
            app.AlphaValueLabel.Text = sprintf('%.2f', event.Value);
        end

        function onAlphaChanged(app, event)
            app.AlphaValueLabel.Text = sprintf('%.2f', event.Value);
        end

        function onRunInference(app, ~)
            progressDialog = [];
            pythonExe = '';
            try
                imagePath = strtrim(app.InputFileField.Value);
                pythonValue = strtrim(app.PythonField.Value);
                weightsPath = strtrim(app.WeightsField.Value);

                validateFile(app, imagePath, 'Citra masukan');
                validateFile(app, weightsPath, 'Checkpoint model');
                validateFile(app, app.InferenceScript, 'Script predict_semantic.py');

                pythonExe = resolvePythonExecutable(app, pythonValue);

                runDir = fullfile(tempdir, 'SegmentasiCitra', ...
                    ['run_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'))]);
                if ~isfolder(runDir)
                    mkdir(runDir);
                end
                maskPath = fullfile(runDir, 'mask.png');
                overlayPath = fullfile(runDir, 'overlay.png');
                metadataPath = fullfile(runDir, 'metadata.json');

                try
                    showImage(app, app.AxesInput, imread(imagePath), 'Citra Masukan');
                catch
                    % Validasi detail tetap dilakukan oleh Python; preview gagal
                    % tidak boleh menghalangi proses inferensi.
                end
                clearResultPanels(app);
                setStatus(app, 'Menyiapkan Python in-process...', 'busy');
                app.RunButton.Enable = 'off';
                app.SaveButton.Enable = 'off';
                app.OpenOutputButton.Enable = 'off';
                drawnow;

                progressDialog = uiprogressdlg(app.UIFigure, ...
                    'Title', 'Inferensi DeepLabV3+', ...
                    'Message', 'Menyiapkan Python in-process...', ...
                    'Indeterminate', 'on');

                [pythonExe, pyModule] = preparePythonEnvironment(app, pythonExe);
                progressDialog.Message = 'Memuat model dan memproses citra...';
                drawnow;

                startTime = tic;
                runInProcessInference(app, pyModule, imagePath, ...
                    weightsPath, maskPath, overlayPath, metadataPath);
                wallSeconds = toc(startTime);

                if ~isfile(metadataPath)
                    error('SegmentasiCitraApp:MissingMetadata', ...
                        ['Python selesai tanpa menghasilkan metadata JSON. ' ...
                        'Pastikan model/predict_semantic.py versi terbaru digunakan.']);
                end

                metadata = readMetadata(app, metadataPath);
                showImage(app, app.AxesMask, imread(char(metadata.outputs.mask)), 'Mask Berwarna');
                showImage(app, app.AxesOverlay, imread(char(metadata.outputs.overlay)), 'Overlay');
                updateResults(app, metadata, wallSeconds);

                app.LastResult = struct( ...
                    'imagePath', imagePath, ...
                    'maskPath', char(metadata.outputs.mask), ...
                    'overlayPath', char(metadata.outputs.overlay), ...
                    'metadataPath', metadataPath, ...
                    'outputDir', runDir, ...
                    'pythonExe', pythonExe, ...
                    'pythonModule', app.LastPythonModulePath);
                app.LastOutputDir = runDir;
                app.SaveButton.Enable = 'on';
                app.OpenOutputButton.Enable = 'on';
                setStatus(app, sprintf('Selesai dalam %.2f detik. Output disimpan di: %s', ...
                    wallSeconds, runDir), 'success');
            catch ME
                if ~isempty(progressDialog) && isvalid(progressDialog)
                    delete(progressDialog);
                end
                progressDialog = [];
                message = describeRunError(app, ME, pythonExe);
                setStatus(app, ['Gagal: ' message], 'error');
                uialert(app.UIFigure, message, 'Inferensi Gagal', ...
                    'Icon', 'error', 'Interpreter', 'none');
            end
            if ~isempty(progressDialog) && isvalid(progressDialog)
                delete(progressDialog);
            end
            app.RunButton.Enable = 'on';
        end

        function [pythonExe, module] = preparePythonEnvironment(app, pythonExe)
            % Memilih interpreter untuk pyenv lalu mengimpor modul inferensi.
            % Inferensi berjalan di dalam proses MATLAB, bukan lewat system().
            pe = pyenv;
            if strcmpi(pe.Status, 'Loaded')
                if ~pythonEnvironmentMatches(app, pythonExe)
                    loadedExe = char(pe.Executable);
                    if isempty(loadedExe)
                        loadedExe = '(tidak diketahui)';
                    end
                    error('SegmentasiCitraApp:PythonEnvLocked', ...
                        ['MATLAB sudah memuat Python lain: %s\n\n' ...
                        'MATLAB tidak bisa mengganti interpreter setelah dimuat. ' ...
                        'Tutup lalu buka ulang MATLAB, kemudian langsung jalankan GUI ' ...
                        'dan klik "Jalankan Inferensi" (jangan memanggil py.* lebih dulu).\n\n' ...
                        'Python yang dipilih: %s\n' ...
                        'Jika perlu, setelah restart jalankan:\npyenv(''Version'', ''%s'');'], ...
                        loadedExe, pythonExe, pythonExe);
                end
            else
                try
                    pyenv('Version', pythonExe);
                catch ME
                    error('SegmentasiCitraApp:PythonEnvFailed', ...
                        ['MATLAB gagal memakai Python ini:\n%s\n\n%s\n\n' ...
                        'Pilih path lengkap ke Python di dalam venv. Versi Python harus ' ...
                        'didukung MATLAB dan memiliki libpython bersama (shared library).'], ...
                        pythonExe, pythonErrorMessage(app, ME));
                end
                try
                    py.importlib.import_module('sys');
                catch ME
                    error('SegmentasiCitraApp:PythonEnvFailed', ...
                        'MATLAB tidak dapat memuat Python: %s', ...
                        pythonErrorMessage(app, ME));
                end
                if ~strcmpi(pyenv().Status, 'Loaded')
                    error('SegmentasiCitraApp:PythonEnvFailed', ...
                        'Python belum berhasil dimuat oleh MATLAB. Periksa path Python.');
                end
                if ~pythonEnvironmentMatches(app, pythonExe)
                    error('SegmentasiCitraApp:PythonEnvMismatch', ...
                        ['MATLAB memuat environment Python yang berbeda dari pilihan GUI. ' ...
                        'Tutup dan buka ulang MATLAB, lalu coba lagi tanpa perintah py.* lain.']);
                end
            end
            module = importPredictModule(app, pythonExe);
        end

        function module = importPredictModule(app, pythonExe)
            scriptPath = app.InferenceScript;
            if ~isempty(app.PyModule) && strcmp(app.PyModulePython, pythonExe) && ...
                    strcmp(app.PyModuleScript, scriptPath)
                module = app.PyModule;
                return;
            end

            moduleDir = fileparts(scriptPath);
            py.sys.path().insert(int32(0), moduleDir);

            % Bersihkan modul lama yang mungkin berasal dari path berbeda.
            try
                pyModules = py.sys.modules;
                existing = pyModules{'predict_semantic'};
                existingFile = char(py.getattr(existing, '__file__'));
                if ~samePath(app, existingFile, scriptPath)
                    pyModules.pop('predict_semantic', py.None);
                end
            catch
                % Modul belum dimuat; tidak ada yang perlu dibersihkan.
            end

            try
                module = py.importlib.import_module('predict_semantic');
            catch ME
                error('SegmentasiCitraApp:PythonImportFailed', ...
                    ['Modul predict_semantic gagal diimpor dari:\n%s\n\n%s\n\n' ...
                    'Instal dependensi untuk Python ini:\n%s'], ...
                    scriptPath, pythonErrorMessage(app, ME), ...
                    pipCommand(app, pythonExe));
            end

            importedFile = char(py.getattr(module, '__file__'));
            if ~samePath(app, importedFile, scriptPath)
                error('SegmentasiCitraApp:PythonImportFailed', ...
                    ['predict_semantic dimuat dari path lain:\n%s\n' ...
                    'seharusnya:\n%s\n\nTutup dan buka ulang MATLAB, lalu coba lagi.'], ...
                    importedFile, scriptPath);
            end

            depsReady = false;
            try
                depsReady = logical(py.getattr(module, '_DEPS_READY'));
            catch
            end
            if ~depsReady
                depError = 'tidak diketahui';
                try
                    importError = py.getattr(module, '_IMPORT_ERROR');
                    depError = char(py.str(importError));
                catch
                end
                try
                    pyModules = py.sys.modules;
                    pyModules.pop('predict_semantic', py.None);
                catch
                end
                error('SegmentasiCitraApp:PythonDependencies', ...
                    ['Dependensi Python belum lengkap untuk environment ini.\n' ...
                    'Detail: %s\n\nPython: %s\n\nInstal dengan perintah:\n%s\n\n' ...
                    'Setelah instalasi selesai, klik "Jalankan Inferensi" lagi.'], ...
                    depError, pythonExe, pipCommand(app, pythonExe));
            end

            app.PyModule = module;
            app.PyModulePython = pythonExe;
            app.PyModuleScript = scriptPath;
            app.LastPythonModulePath = importedFile;
        end

        function runInProcessInference(app, module, imagePath, ...
                weightsPath, maskPath, overlayPath, metadataPath)
            % Memanggil API Python yang sama dengan CLI, tanpa subprocess.
            try
                module.predict_to_files( ...
                    char(imagePath), ...
                    char(weightsPath), ...
                    char(maskPath), ...
                    char(overlayPath), ...
                    double(app.AlphaSlider.Value), ...
                    py.bool(logical(app.TTACheckBox.Value)), ...
                    char(metadataPath), ...
                    char(app.DeviceDropDown.Value));
            catch ME
                if strcmp(ME.identifier, 'MATLAB:Python:PyException')
                    error('SegmentasiCitraApp:InferenceFailed', '%s', ...
                        pythonErrorMessage(app, ME));
                end
                rethrow(ME);
            end
        end

        function pythonExe = resolvePythonExecutable(app, value)
            value = strtrim(char(value));
            if isempty(value)
                error('SegmentasiCitraApp:MissingPython', ...
                    ['Python belum diisi. Isi path lengkap ke .venv/bin/python3.12 ' ...
                    '(Linux/macOS) atau .venv\Scripts\python.exe (Windows).']);
            end
            if startsWith(value, '~')
                homeDir = getenv('HOME');
                if isempty(homeDir)
                    homeDir = getenv('USERPROFILE');
                end
                if ~isempty(homeDir)
                    value = fullfile(homeDir, regexprep(value, '^~[\\/]?', ''));
                end
            end

            if isAbsolutePath(app, value)
                candidate = value;
            else
                candidate = fullfile(pwd, value);
            end
            if isfile(candidate)
                pythonExe = candidate;
                return;
            end

            if looksLikePath(app, value)
                error('SegmentasiCitraApp:MissingPython', ...
                    ['Executable Python tidak ditemukan: %s. ' ...
                    'Gunakan path lengkap ke file Python, bukan nama folder.'], value);
            end

            % Dukungan nama perintah (misalnya python3) tanpa subprocess:
            % cari langsung di folder-folder PATH.
            pathEntries = strsplit(getenv('PATH'), pathsep);
            if ispc
                names = {value, [value '.exe']};
            else
                names = {value};
            end
            for i = 1:numel(pathEntries)
                if isempty(pathEntries{i})
                    continue;
                end
                for j = 1:numel(names)
                    candidate = fullfile(pathEntries{i}, names{j});
                    if isfile(candidate)
                        pythonExe = candidate;
                        return;
                    end
                end
            end

            error('SegmentasiCitraApp:MissingPython', ...
                ['Executable Python "%s" tidak ditemukan di PATH. ' ...
                'Gunakan path lengkap ke .venv/bin/python3.12.'], value);
        end

        function tf = pythonEnvironmentMatches(app, pythonExe)
            % True bila environment Python yang sudah dimuat sama dengan pilihan.
            tf = false;
            pe = pyenv;
            if ~strcmpi(pe.Status, 'Loaded')
                return;
            end

            targetRoot = pythonEnvironmentRoot(app, pythonExe);
            loadedPrefix = '';
            try
                loadedPrefix = char(py.sys.prefix);
            catch
            end
            if ~isempty(loadedPrefix) && samePath(app, targetRoot, loadedPrefix)
                tf = true;
            else
                % Fallback untuk lokasi python yang berupa symlink.
                targetDir = fileparts(pythonExe);
                try
                    if samePath(app, targetDir, fileparts(char(pe.Executable))) || ...
                            samePath(app, targetDir, fileparts(char(py.sys.executable)))
                        tf = true;
                    end
                catch
                end
            end

            if tf
                hint = pythonVersionHint(app, pythonExe);
                if ~isempty(hint)
                    try
                        info = py.sys.version_info;
                        loadedVersion = sprintf('%d.%d', ...
                            double(py.getattr(info, 'major')), ...
                            double(py.getattr(info, 'minor')));
                        tf = strcmp(loadedVersion, hint);
                    catch
                        % Metadata versi tidak tersedia; jangan tolak
                        % environment yang path-nya sudah cocok.
                    end
                end
            end
        end

        function root = pythonEnvironmentRoot(~, pythonExe)
            exeDir = fileparts(pythonExe);
            [parentDir, leaf] = fileparts(exeDir);
            if any(strcmpi(leaf, {'bin', 'Scripts'}))
                root = parentDir;
            else
                root = exeDir;
            end
        end

        function hint = pythonVersionHint(~, pythonExe)
            [~, name] = fileparts(pythonExe);
            token = regexp(name, '^python(\d+)\.(\d+)$', 'tokens', 'once');
            if isempty(token)
                token = regexp(name, '^python(\d)(\d+)$', 'tokens', 'once');
            end
            if isempty(token)
                hint = '';
            else
                hint = sprintf('%s.%s', token{1}, token{2});
            end
        end

        function tf = samePath(app, left, right)
            tf = strcmpi(canonicalPath(app, left), canonicalPath(app, right));
        end

        function value = canonicalPath(~, value)
            value = char(value);
            try
                value = char(java.io.File(value).getCanonicalPath());
            catch
                % Java tidak tersedia; bandingkan path apa adanya.
            end
            if ispc
                value = lower(value);
            end
        end

        function tf = isAbsolutePath(~, value)
            if ispc
                tf = ~isempty(regexp(value, '^[A-Za-z]:[\\/]', 'once')) || ...
                    startsWith(value, '\\');
            else
                tf = startsWith(value, '/');
            end
        end

        function command = pipCommand(app, pythonExe)
            if isempty(pythonExe)
                pythonExe = strtrim(app.PythonField.Value);
            end
            if isempty(pythonExe)
                pythonExe = 'python';
            end
            requirements = fullfile(app.RootDir, 'model', 'requirements.txt');
            command = sprintf('"%s" -m pip install -r "%s"', ...
                char(pythonExe), requirements);
        end

        function message = pythonErrorMessage(~, ME)
            message = char(ME.message);
            message = regexprep(message, '^Python Error:\s*', '');
        end

        function message = describeRunError(app, ME, pythonExe)
            if strcmp(ME.identifier, 'MATLAB:Python:PyException')
                message = pythonErrorMessage(app, ME);
            else
                message = ME.message;
            end
            needsInstall = contains(message, 'Dependensi Python') || ...
                contains(message, 'No module named') || ...
                contains(message, 'ModuleNotFoundError');
            if needsInstall
                installCommand = pipCommand(app, pythonExe);
                if ~contains(message, installCommand)
                    message = sprintf('%s\n\nPerintah instal untuk Python ini:\n%s', ...
                        message, installCommand);
                end
            end
        end

        function metadata = readMetadata(~, metadataPath)
            try
                metadata = jsondecode(fileread(metadataPath));
            catch ME
                error('SegmentasiCitraApp:InvalidMetadata', ...
                    'Metadata JSON tidak dapat dibaca: %s', ME.message);
            end
            if ~isfield(metadata, 'ok') || ~logical(metadata.ok)
                error('SegmentasiCitraApp:InvalidMetadata', ...
                    'Metadata JSON tidak menyatakan hasil yang berhasil.');
            end
        end

        function updateResults(app, metadata, wallSeconds)
            classes = metadata.classes;
            count = numel(classes);
            coverage = zeros(count, 1);
            colors = zeros(count, 3);
            names = cell(count, 1);
            pixels = zeros(count, 1);
            for i = 1:count
                coverage(i) = double(classes(i).coverage_pct);
                names{i} = char(classes(i).name);
                pixels(i) = double(classes(i).pixels);
                color = double(reshape(classes(i).color, 1, []));
                if numel(color) < 3
                    color = [204 204 204];
                end
                colors(i, :) = max(0, min(1, color(1:3) / 255));
            end
            [~, order] = sort(coverage, 'descend');

            data = cell(count, 4);
            sortedColors = zeros(count, 3);
            for idx = 1:count
                i = order(idx);
                data{idx, 1} = names{i};
                data{idx, 2} = '';
                data{idx, 3} = pixels(i);
                data{idx, 4} = sprintf('%.2f', coverage(i));
                sortedColors(idx, :) = colors(i, :);
            end
            app.ClassTable.Data = data;
            removeStyle(app.ClassTable);
            for idx = 1:count
                style = uistyle('BackgroundColor', sortedColors(idx, :));
                addStyle(app.ClassTable, style, 'cell', [idx, 2]);
            end

            app.InfoTextArea.Value = buildSummary(app, metadata, wallSeconds);
        end

        function lines = buildSummary(app, metadata, wallSeconds)
            % Ringkasan analisis; persentase selalu disebut sebagai coverage.
            if isfield(metadata, 'device') && isfield(metadata.device, 'name')
                deviceName = char(metadata.device.name);
            else
                deviceName = '-';
            end
            if logical(metadata.settings.tta)
                ttaText = 'aktif (flip horizontal)';
            else
                ttaText = 'nonaktif';
            end
            if isfield(metadata, 'system') && isfield(metadata.system, 'python_version')
                pythonLine = sprintf('Python       : %s (in-process)', ...
                    char(metadata.system.python_version));
            else
                pythonLine = 'Python       : (info tidak tersedia)';
            end
            if isempty(app.LastPythonModulePath)
                moduleLine = 'Modul Python : predict_semantic.py';
            else
                moduleLine = sprintf('Modul Python : %s', app.LastPythonModulePath);
            end

            lines = { ...
                'CATATAN: persentase kelas = CAKUPAN AREA PIKEL, BUKAN akurasi.'; ...
                'Tidak ada ground-truth pada citra masukan.'; ...
                ''; ...
                sprintf('Citra        : %s', char(metadata.image.name)); ...
                sprintf('Dimensi      : %d x %d piksel', ...
                    metadata.image.width, metadata.image.height); ...
                sprintf('Model        : %s / %s (%d kelas CamVid)', ...
                    char(metadata.model.architecture), char(metadata.model.encoder), ...
                    metadata.model.num_classes); ...
                sprintf('Input model  : %d x %d piksel', ...
                    metadata.model.input_width, metadata.model.input_height); ...
                sprintf('Checkpoint   : %s', char(metadata.model.checkpoint_name)); ...
                sprintf('Perangkat    : %s (%s)', char(metadata.device.type), deviceName); ...
                pythonLine; ...
                moduleLine; ...
                sprintf('TTA          : %s', ttaText); ...
                sprintf('Alpha overlay: %.2f', metadata.settings.overlay_alpha); ...
                sprintf(['Waktu        : %.2f s (dinding) | Python total %.2f s | ' ...
                    'inferensi %.2f s'], wallSeconds, ...
                    metadata.timings.total_seconds, metadata.timings.inference_seconds); ...
                sprintf('Mask         : %s', char(metadata.outputs.mask)); ...
                sprintf('Overlay      : %s', char(metadata.outputs.overlay)); ...
                sprintf('Metadata     : %s', char(metadata.outputs.metadata)); ...
                sprintf('Versi skrip  : %s', char(metadata.tool.version))};
        end

        function showImage(~, ax, img, titleText)
            if isempty(img)
                return;
            end
            if ismatrix(img)
                img = repmat(img, [1 1 3]);
            elseif size(img, 3) > 3
                img = img(:, :, 1:3);
            end
            image(ax, img);
            axis(ax, 'image');
            axis(ax, 'off');
            ax.YDir = 'reverse';
            title(ax, titleText, 'Interpreter', 'none');
        end

        function showPlaceholder(~, ax, message)
            cla(ax);
            axis(ax, 'off');
            text(ax, 0.5, 0.5, message, ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'Color', [0.45 0.48 0.52], ...
                'FontSize', 11, ...
                'Interpreter', 'none');
        end

        function clearResultPanels(app)
            showPlaceholder(app, app.AxesMask, 'Sedang memproses...');
            showPlaceholder(app, app.AxesOverlay, 'Sedang memproses...');
            clearAnalysis(app);
        end

        function clearAnalysis(app)
            app.ClassTable.Data = cell(0, 4);
            removeStyle(app.ClassTable);
            app.InfoTextArea.Value = {'Belum ada hasil inferensi.'; ...
                ''; ...
                'Persentase kelas adalah cakupan area piksel, BUKAN akurasi.'};
        end

        function setStatus(app, text, kind)
            app.StatusLabel.Text = text;
            switch lower(kind)
                case 'success'
                    app.StatusLabel.FontColor = [0.05 0.45 0.15];
                case 'error'
                    app.StatusLabel.FontColor = [0.72 0.10 0.10];
                case 'warn'
                    app.StatusLabel.FontColor = [0.65 0.40 0.05];
                case 'busy'
                    app.StatusLabel.FontColor = [0.35 0.30 0.05];
                otherwise
                    app.StatusLabel.FontColor = [0.25 0.29 0.35];
            end
            drawnow;
        end

        function onSaveResults(app, ~)
            if isempty(app.LastResult)
                return;
            end
            folder = uigetdir(app.LastResult.outputDir, 'Pilih folder penyimpanan hasil');
            if isequal(folder, 0)
                return;
            end
            [~, base] = fileparts(app.LastResult.imagePath);
            stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
            try
                copyfile(app.LastResult.maskPath, ...
                    fullfile(folder, sprintf('%s_mask_%s.png', base, stamp)));
                copyfile(app.LastResult.overlayPath, ...
                    fullfile(folder, sprintf('%s_overlay_%s.png', base, stamp)));
                copyfile(app.LastResult.metadataPath, ...
                    fullfile(folder, sprintf('%s_metadata_%s.json', base, stamp)));
                setStatus(app, sprintf('Hasil disalin ke: %s', folder), 'success');
            catch ME
                setStatus(app, ['Gagal menyimpan hasil: ' ME.message], 'error');
                uialert(app.UIFigure, ME.message, 'Gagal Menyimpan Hasil', 'Icon', 'error', 'Interpreter', 'none');
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
                elseif ismac
                    [status, ~] = system(['open ' shellQuote(app, folder) ' >/dev/null 2>&1 &']);
                    if status ~= 0
                        error('Perintah "open" gagal (exit code %d).', status);
                    end
                else
                    [status, ~] = system(['xdg-open ' shellQuote(app, folder) ' >/dev/null 2>&1 &']);
                    if status ~= 0
                        error('Perintah "xdg-open" gagal (exit code %d).', status);
                    end
                end
            catch ME
                uialert(app.UIFigure, ME.message, ...
                    'Gagal Membuka Folder', 'Icon', 'warning', 'Interpreter', 'none');
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

        function tf = looksLikePath(~, value)
            tf = contains(value, filesep) || (ispc && contains(value, '/'));
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
            if isempty(folder)
                folder = pwd;
            end
        end

        function quoted = shellQuote(~, value)
            % Quoting path agar aman untuk sh (Unix) maupun cmd.exe (Windows).
            value = char(value);
            if ispc
                quoted = ['"' strrep(value, '"', '""') '"'];
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
