classdef SegmentasiCitraPython
    % Integrasi pyenv in-process dan inferensi DeepLabV3+ untuk GUI.

    methods (Static)
        function pythonExe = resolveExecutable(value)
            value = strtrim(char(value));
            if isempty(value)
                error('SegmentasiCitraApp:MissingPython', ...
                    ['Python belum diisi. Isi path lengkap ke .venv/bin/python3.12 ' ...
                    '(Linux/macOS) atau .venv\Scripts\python.exe (Windows).']);
            end
            if startsWith(value, '~')
                homeDir = getenv('HOME');
                if isempty(homeDir), homeDir = getenv('USERPROFILE'); end
                if ~isempty(homeDir)
                    value = fullfile(homeDir, regexprep(value, '^~[\\/]?', ''));
                end
            end
            if ispc
                isAbs = ~isempty(regexp(value, '^[A-Za-z]:[\\/]', 'once')) || ...
                    startsWith(value, '\\');
            else
                isAbs = startsWith(value, '/');
            end
            if isAbs, candidate = value; else, candidate = fullfile(pwd, value); end
            if isfile(candidate), pythonExe = candidate; return; end
            if contains(value, filesep) || (ispc && contains(value, '/'))
                error('SegmentasiCitraApp:MissingPython', ...
                    ['Executable Python tidak ditemukan: %s. ' ...
                    'Gunakan path lengkap ke file Python, bukan nama folder.'], value);
            end
            % Dukungan nama perintah (misalnya python3) tanpa subprocess:
            % cari langsung di folder-folder PATH.
            pathEntries = strsplit(getenv('PATH'), pathsep);
            if ispc, names = {value, [value '.exe']}; else, names = {value}; end
            for i = 1:numel(pathEntries)
                if isempty(pathEntries{i}), continue; end
                for j = 1:numel(names)
                    candidate = fullfile(pathEntries{i}, names{j});
                    if isfile(candidate), pythonExe = candidate; return; end
                end
            end
            error('SegmentasiCitraApp:MissingPython', ...
                ['Executable Python "%s" tidak ditemukan di PATH. ' ...
                'Gunakan path lengkap ke .venv/bin/python3.12.'], value);
        end

        function [pythonExe, module, modulePath] = prepare(pythonExe, scriptPath, ...
                rootDir, fieldValue)
            % Memuat interpreter dengan pyenv lalu mengimpor modul inferensi.
            pe = pyenv;
            if strcmpi(pe.Status, 'Loaded')
                if ~SegmentasiCitraPython.environmentMatches(pythonExe)
                    loadedExe = char(pe.Executable);
                    if isempty(loadedExe), loadedExe = '(tidak diketahui)'; end
                    error('SegmentasiCitraApp:PythonEnvLocked', ...
                        ['MATLAB sudah memuat Python lain: %s\n\n' ...
                        'MATLAB tidak bisa mengganti interpreter setelah dimuat. ' ...
                        'Tutup lalu buka ulang MATLAB, kemudian langsung jalankan GUI ' ...
                        'dan klik "Jalankan Inferensi" (jangan memanggil py.* lebih dulu).' ...
                        '\n\nPython yang dipilih: %s\nJika perlu, setelah restart ' ...
                        'jalankan:\npyenv(''Version'', ''%s'');'], ...
                        loadedExe, pythonExe, pythonExe);
                end
            else
                try pyenv('Version', pythonExe);
                catch ME
                    error('SegmentasiCitraApp:PythonEnvFailed', ...
                        ['MATLAB gagal memakai Python ini:\n%s\n\n%s\n\n' ...
                        'Pilih path lengkap ke Python di dalam venv. Versi Python ' ...
                        'harus didukung MATLAB dan memiliki libpython bersama ' ...
                        '(shared library).'], pythonExe, ...
                        SegmentasiCitraPython.errorMessage(ME));
                end
                try py.importlib.import_module('sys');
                catch ME
                    error('SegmentasiCitraApp:PythonEnvFailed', ...
                        'MATLAB tidak dapat memuat Python: %s', ...
                        SegmentasiCitraPython.errorMessage(ME));
                end
                if ~strcmpi(pyenv().Status, 'Loaded')
                    error('SegmentasiCitraApp:PythonEnvFailed', ...
                        'Python belum berhasil dimuat oleh MATLAB. Periksa path Python.');
                end
                if ~SegmentasiCitraPython.environmentMatches(pythonExe)
                    error('SegmentasiCitraApp:PythonEnvMismatch', ...
                        ['MATLAB memuat environment Python yang berbeda dari ' ...
                        'pilihan GUI. Tutup dan buka ulang MATLAB, lalu coba lagi ' ...
                        'tanpa perintah py.* lain.']);
                end
            end
            [module, modulePath] = SegmentasiCitraPython.importModule(scriptPath, ...
                pythonExe, rootDir, fieldValue);
        end

        function run(module, imagePath, weightsPath, maskPath, overlayPath, ...
                alpha, useTta, device)
            % Memanggil API Python yang sama dengan CLI, tanpa subprocess.
            try
                module.predict_to_files(char(imagePath), char(weightsPath), ...
                    char(maskPath), char(overlayPath), double(alpha), ...
                    py.bool(logical(useTta)), char(device));
            catch ME
                if strcmp(ME.identifier, 'MATLAB:Python:PyException')
                    error('SegmentasiCitraApp:InferenceFailed', '%s', ...
                        SegmentasiCitraPython.errorMessage(ME));
                end
                rethrow(ME);
            end
        end

        function message = describeError(ME, pythonExe, fieldValue, rootDir)
            if strcmp(ME.identifier, 'MATLAB:Python:PyException')
                message = SegmentasiCitraPython.errorMessage(ME);
            else
                message = ME.message;
            end
            needsInstall = contains(message, 'Dependensi Python') || ...
                contains(message, 'No module named') || ...
                contains(message, 'ModuleNotFoundError');
            if needsInstall
                installCommand = SegmentasiCitraPython.pipCommand( ...
                    pythonExe, fieldValue, rootDir);
                if ~contains(message, installCommand)
                    message = sprintf('%s\n\nPerintah instal untuk Python ini:\n%s', ...
                        message, installCommand);
                end
            end
            if contains(message, 'Bobot checkpoint tidak cocok') || ...
                    contains(message, 'Checkpoint tidak valid')
                hint = ['Jika predict_semantic.py baru saja diperbarui, ' ...
                    'tutup lalu buka ulang MATLAB sekali agar modul Python ' ...
                    'lama tidak dipakai.'];
                if ~contains(message, hint)
                    message = sprintf('%s\n\n%s', message, hint);
                end
            end
        end
    end

    methods (Static, Access = private)
        function [module, modulePath] = importModule(scriptPath, pythonExe, ...
                rootDir, fieldValue)
            py.sys.path().insert(int32(0), fileparts(scriptPath));
            sourceStamp = SegmentasiCitraPython.sourceStamp(scriptPath);
            sourceVersion = SegmentasiCitraPython.sourceVersion(scriptPath);
            haveExisting = false; existing = []; stale = false;
            try
                pyModules = py.sys.modules;
                existing = pyModules{'predict_semantic'};
                haveExisting = true;
            catch
            end
            if haveExisting
                existingPath = '';
                try existingPath = char(py.getattr(existing, '__file__')); catch; end
                if isempty(existingPath) || ...
                        ~SegmentasiCitraPython.samePath(existingPath, scriptPath)
                    % Modul lama dari path lain: buang agar diimpor ulang.
                    try
                        pyModules = py.sys.modules;
                        pyModules.pop('predict_semantic', py.None);
                    catch
                    end
                    haveExisting = false;
                else
                    % Modul dari path yang sama bisa saja masih versi lama
                    % (sys.modules tidak otomatis mengikuti perubahan file).
                    loadedStamp = '';
                    try
                        loadedStamp = char(py.getattr(existing, ...
                            '_MATLAB_SCRIPT_STAMP'));
                    catch
                    end
                    loadedVersion = '';
                    try
                        loadedVersion = char(py.getattr(existing, '__version__'));
                    catch
                    end
                    if isempty(loadedStamp)
                        stale = true; % Modul lama belum memiliki penanda.
                    elseif ~strcmp(loadedStamp, sourceStamp)
                        stale = true;
                    elseif ~isempty(sourceVersion) && ...
                            ~strcmp(loadedVersion, sourceVersion)
                        stale = true;
                    end
                end
            end
            try
                if haveExisting && ~stale
                    module = existing;
                elseif haveExisting
                    try
                        module = py.importlib.reload(existing);
                    catch
                        % Reload gagal: bersihkan cache lalu impor dari file.
                        try
                            pyModules = py.sys.modules;
                            pyModules.pop('predict_semantic', py.None);
                        catch
                        end
                        module = py.importlib.import_module('predict_semantic');
                    end
                else
                    module = py.importlib.import_module('predict_semantic');
                end
            catch ME
                error('SegmentasiCitraApp:PythonImportFailed', ...
                    ['Modul predict_semantic gagal diimpor dari:\n%s\n\n%s\n\n' ...
                    'Instal dependensi untuk Python ini:\n%s'], scriptPath, ...
                    SegmentasiCitraPython.errorMessage(ME), ...
                    SegmentasiCitraPython.pipCommand(pythonExe, fieldValue, rootDir));
            end
            modulePath = char(py.getattr(module, '__file__'));
            if ~SegmentasiCitraPython.samePath(modulePath, scriptPath)
                error('SegmentasiCitraApp:PythonImportFailed', ...
                    ['predict_semantic dimuat dari path lain:\n%s\nseharusnya:\n%s' ...
                    '\n\nTutup dan buka ulang MATLAB, lalu coba lagi.'], ...
                    modulePath, scriptPath);
            end
            depsReady = false;
            try depsReady = logical(py.getattr(module, '_DEPS_READY')); catch; end
            if ~depsReady
                depError = 'tidak diketahui';
                try
                    depError = char(py.str(py.getattr(module, '_IMPORT_ERROR')));
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
                    depError, pythonExe, SegmentasiCitraPython.pipCommand( ...
                    pythonExe, fieldValue, rootDir));
            end
            % Penanda isi script saat ini; dipakai untuk mendeteksi modul
            % pada pemanggilan berikutnya tanpa reload.
            try py.setattr(module, '_MATLAB_SCRIPT_STAMP', sourceStamp); catch; end
        end

        function stamp = sourceStamp(scriptPath)
            stamp = '';
            info = dir(scriptPath);
            if isempty(info), return; end
            millis = 0;
            try millis = double(java.io.File(scriptPath).lastModified()); catch; end
            if millis <= 0, millis = double(info.datenum); end
            stamp = sprintf('%.0f:%0.0f', millis, double(info.bytes));
        end

        function version = sourceVersion(scriptPath)
            version = '';
            try
                text = fileread(scriptPath);
                token = regexp(text, ...
                    '__version__\s*=\s*[''"]([^''"]+)[''"]', ...
                    'tokens', 'once');
                if ~isempty(token), version = token{1}; end
            catch
            end
        end

        function tf = environmentMatches(pythonExe)
            tf = false; pe = pyenv;
            if ~strcmpi(pe.Status, 'Loaded'), return; end
            exeDir = fileparts(pythonExe); [parentDir, leaf] = fileparts(exeDir);
            if any(strcmpi(leaf, {'bin', 'Scripts'})), targetRoot = parentDir;
            else, targetRoot = exeDir; end
            loadedPrefix = '';
            try loadedPrefix = char(py.sys.prefix); catch; end
            if ~isempty(loadedPrefix) && ...
                    SegmentasiCitraPython.samePath(targetRoot, loadedPrefix)
                tf = true;
            else
                % Fallback untuk lokasi python yang berupa symlink.
                targetDir = fileparts(pythonExe);
                try
                    if SegmentasiCitraPython.samePath(targetDir, ...
                            fileparts(char(pe.Executable))) || ...
                            SegmentasiCitraPython.samePath(targetDir, ...
                            fileparts(char(py.sys.executable)))
                        tf = true;
                    end
                catch
                end
            end
            if tf
                [~, name] = fileparts(pythonExe);
                token = regexp(name, '^python(\d+)\.(\d+)$', 'tokens', 'once');
                if isempty(token)
                    token = regexp(name, '^python(\d)(\d+)$', 'tokens', 'once');
                end
                if ~isempty(token)
                    hint = sprintf('%s.%s', token{1}, token{2});
                    try
                        info = py.sys.version_info;
                        loadedVersion = sprintf('%d.%d', ...
                            double(py.getattr(info, 'major')), ...
                            double(py.getattr(info, 'minor')));
                        tf = strcmp(loadedVersion, hint);
                    catch
                        % Metadata versi tidak tersedia; path sudah cocok.
                    end
                end
            end
        end

        function command = pipCommand(pythonExe, fieldValue, rootDir)
            if isempty(pythonExe), pythonExe = strtrim(fieldValue); end
            if isempty(pythonExe), pythonExe = 'python'; end
            command = sprintf('"%s" -m pip install -r "%s"', char(pythonExe), ...
                fullfile(rootDir, 'model', 'requirements.txt'));
        end

        function tf = samePath(left, right)
            left = char(left); right = char(right);
            try left = char(java.io.File(left).getCanonicalPath()); catch; end
            try right = char(java.io.File(right).getCanonicalPath()); catch; end
            if ispc, left = lower(left); right = lower(right); end
            tf = strcmpi(left, right);
        end

        function message = errorMessage(ME)
            message = regexprep(char(ME.message), '^Python Error:\s*', '');
        end
    end
end
