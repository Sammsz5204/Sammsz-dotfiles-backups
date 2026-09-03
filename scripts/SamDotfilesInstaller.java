import java.io.*;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermission;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Instalador em Java para o rice SamDotfiles
 * (https://github.com/Sammsz5204/SamDotfiles).
 *
 * Reimplementa em Java o que o scripts/install.sh original faz:
 *   1. Clona o repositório (se necessário)
 *   2. Instala os pacotes via pacman (Arch Linux)
 *   3. Instala as fontes (as do repo + JetBrainsMono Nerd Font atualizada)
 *   4. Torna scripts (.sh/.lua/.py) executáveis
 *   5. Faz backup de configs existentes e symlinka os dotfiles pra ~/.config
 *   6. Prepara ~/Pictures/Wallpapers e gera o tema inicial
 *
 * Uso:
 *   javac SamDotfilesInstaller.java
 *   java SamDotfilesInstaller [opções]
 *
 * Opções:
 *   --dir <path>       Usa uma cópia local já existente do repo em vez de clonar
 *   --skip-packages     Não instala pacotes via pacman
 *   --skip-fonts        Não instala fontes
 *   --skip-clone        Não tenta clonar, assume que --dir (ou o cwd) já é o repo
 *   --yes, -y            Não pede confirmação antes de começar
 *   --help, -h           Mostra esta ajuda
 */
public class SamDotfilesInstaller {

    // ── Cores ANSI ──────────────────────────────────────────────
    static final String RED = "\u001B[0;31m";
    static final String GREEN = "\u001B[0;32m";
    static final String YELLOW = "\u001B[1;33m";
    static final String BLUE = "\u001B[0;34m";
    static final String CYAN = "\u001B[0;36m";
    static final String BOLD = "\u001B[1m";
    static final String NC = "\u001B[0m";

    static final String REPO_URL = "https://github.com/Sammsz5204/SamDotfiles.git";
    static final String NERD_FONT_URL =
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip";

    // Módulo QML externo usado por StartupSplash.qml e LockSurface.qml
    // (import M3Shapes / MaterialShape) — não faz parte do repo SamDotfiles
    // nem tem pacote no pacman/AUR isolado, então precisa ser buildado do
    // fonte e instalado no QML import path do Qt6.
    static final String M3SHAPES_REPO_URL = "https://github.com/soramanew/m3shapes.git";

    // ── Pacotes necessários (Arch / pacman) ─────────────────────
    static final String[] PACKAGES = {
            // Desktop Environment & Compositor
            "hyprland", "hyprlock", "hyprpaper", "swaync", "cava", "kitty", "ghostty",
            // Suporte a Temas e Scripts (LUA / ImageMagick / Python)
            "imagemagick", "lua", "lua-lgi", "lua51", "lua51-lgi", "python", "python-pip",
            // Apps & Utilitários de Sistema
            "nautilus", "networkmanager", "network-manager-applet", "bluez", "bluez-utils",
            "btop", "neovim", "papirus-icon-theme", "nwg-look", "playerctl", "grim", "slurp",
            "firefox", "discord", "flatpak", "mpd", "rmpc", "mpc",
            // Build & Fontes
            "base-devel", "git", "unzip", "ttf-font-awesome", "ttf-jetbrains-mono-nerd",
            "cowsay", "sl",
            // Build do módulo QML M3Shapes (StartupSplash/LockSurface)
            "cmake", "qt6-declarative", "qt6-base"
    };

    // Mapeamento: pasta no repo -> destino em ~/.config
    static final String[] CONFIG_DIRS = {
            "btop", "hypr", "kitty", "nvim", "nwg-look", "quickshell", "scripts"
    };

    Path dotfilesDir;
    Path homeDir = Paths.get(System.getProperty("user.home"));
    Path configDir = homeDir.resolve(".config");
    Path fontsDir = homeDir.resolve(".local/share/fonts");
    Path wallpaperDir = homeDir.resolve("Pictures/Wallpapers");
    Path backupDir;

    boolean skipPackages = false;
    boolean skipFonts = false;
    boolean skipClone = false;
    boolean skipM3Shapes = false;
    boolean assumeYes = false;
    String userDir = null;

    public static void main(String[] args) throws Exception {
        // Força UTF-8 na saída para não bagunçar os acentos/emojis em qualquer locale.
        System.setOut(new PrintStream(new FileOutputStream(FileDescriptor.out), true, "UTF-8"));
        System.setErr(new PrintStream(new FileOutputStream(FileDescriptor.err), true, "UTF-8"));

        SamDotfilesInstaller installer = new SamDotfilesInstaller();
        installer.parseArgs(args);
        installer.run();
    }

    void parseArgs(String[] args) {
        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--dir":
                    if (i + 1 < args.length) userDir = args[++i];
                    break;
                case "--skip-packages":
                    skipPackages = true;
                    break;
                case "--skip-fonts":
                    skipFonts = true;
                    break;
                case "--skip-clone":
                    skipClone = true;
                    break;
                case "--skip-m3shapes":
                    skipM3Shapes = true;
                    break;
                case "--yes":
                case "-y":
                    assumeYes = true;
                    break;
                case "--help":
                case "-h":
                    printHelp();
                    System.exit(0);
                    break;
                default:
                    warn("Argumento desconhecido ignorado: " + args[i]);
            }
        }
    }

    void printHelp() {
        System.out.println("""
                Uso: java SamDotfilesInstaller [opcoes]

                  --dir <path>      Usa uma copia local ja existente do repo em vez de clonar
                  --skip-packages   Nao instala pacotes via pacman
                  --skip-fonts      Nao instala fontes
                  --skip-clone      Nao tenta clonar (assume --dir ou cwd como repo)
                  --skip-m3shapes   Nao builda/instala o modulo QML M3Shapes
                  --yes, -y         Nao pede confirmacao antes de comecar
                  --help, -h        Mostra esta ajuda
                """);
    }

    // ── Logging ──────────────────────────────────────────────────
    static void info(String msg) { System.out.println(CYAN + BOLD + "[•] " + NC + msg); }
    static void success(String msg) { System.out.println(GREEN + BOLD + "[✓] " + NC + msg); }
    static void warn(String msg) { System.out.println(YELLOW + BOLD + "[!] " + NC + msg); }
    static void error(String msg) { System.err.println(RED + BOLD + "[✗] " + NC + msg); }
    static void header(String msg) {
        System.out.println("\n" + BLUE + BOLD + "── " + msg + " ──────────────────────────────" + NC);
    }

    void printBanner() {
        System.out.println(BOLD + """
                  ____        _   _   _ ____  _ _\s
                 / ___|  __ _| |_| |_| |  _ \\(_) | ___ ___\s
                 \\___ \\ / _` | __| __| | |_) | | |/ _ / __|
                  ___) | (_| | |_| |_| |  _ <| | |  __\\__ \\
                 |____/ \\__,_|\\__|\\__|_|_| \\_\\_|_|\\___|___/

                     SamDotfiles installer (Java edition)
                """ + NC);
    }

    // ── Execução principal ──────────────────────────────────────
    void run() throws Exception {
        printBanner();

        if (!System.getProperty("os.name").toLowerCase().contains("linux")) {
            warn("Este rice foi feito para Arch Linux + Hyprland. Rodar em " +
                    System.getProperty("os.name") + " provavelmente não vai funcionar.");
        }

        if (!assumeYes) {
            System.out.print(BOLD + "Continuar com a instalação? [s/N] " + NC);
            String resp = new BufferedReader(new InputStreamReader(System.in)).readLine();
            if (resp == null || !resp.trim().equalsIgnoreCase("s")) {
                info("Instalação cancelada pelo usuário.");
                return;
            }
        }

        resolveDotfilesDir();

        backupDir = homeDir.resolve(".config-backup/" +
                LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss")));

        if (!skipPackages) installPackages(); else info("Pulando instalação de pacotes (--skip-packages).");
        if (!skipFonts) installFonts(); else info("Pulando instalação de fontes (--skip-fonts).");

        makeScriptsExecutable();
        linkDotfiles();
        if (!skipM3Shapes) installM3Shapes(); else info("Pulando build do M3Shapes (--skip-m3shapes).");
        setupWallpapersAndTheme();

        System.out.println();
        success("Tudo pronto! Coloque seus wallpapers em " + wallpaperDir +
                " e reinicie a sessão do Hyprland. 🎉");
        System.out.println();
        if (Files.isDirectory(backupDir)) {
            info("Backups das configs antigas salvos em: " + backupDir);
        }
    }

    // ── Etapa 0: garantir que temos o repo local ────────────────
    void resolveDotfilesDir() throws IOException, InterruptedException {
        header("Preparando o repositório");

        if (userDir != null) {
            dotfilesDir = Paths.get(userDir).toAbsolutePath().normalize();
            if (!looksLikeRepo(dotfilesDir)) {
                error("O diretório informado em --dir (" + dotfilesDir + ") não parece ser o SamDotfiles.");
                System.exit(1);
            }
            success("Usando repositório em: " + dotfilesDir);
            return;
        }

        Path cwd = Paths.get("").toAbsolutePath();
        if (looksLikeRepo(cwd)) {
            dotfilesDir = cwd;
            success("Rodando de dentro do repositório: " + dotfilesDir);
            return;
        }

        Path candidate = cwd.resolve("SamDotfiles");
        if (looksLikeRepo(candidate)) {
            dotfilesDir = candidate;
            success("Repositório encontrado em: " + dotfilesDir);
            return;
        }

        if (skipClone) {
            error("--skip-clone foi usado mas nenhum repositório válido foi encontrado.");
            System.exit(1);
        }

        info("Repositório não encontrado localmente. Clonando de " + REPO_URL + " ...");
        int code = exec(cwd, "git", "clone", "--depth", "1", REPO_URL, candidate.toString());
        if (code != 0 || !looksLikeRepo(candidate)) {
            error("Falha ao clonar o repositório. Verifique se o 'git' está instalado e sua conexão.");
            System.exit(1);
        }
        dotfilesDir = candidate;
        success("Repositório clonado em: " + dotfilesDir);
    }

    boolean looksLikeRepo(Path dir) {
        return Files.isDirectory(dir.resolve("hypr")) && Files.isDirectory(dir.resolve("quickshell"));
    }

    // ── Etapa 1: pacotes via pacman ──────────────────────────────
    void installPackages() throws IOException, InterruptedException {
        header("Instalando pacotes");

        if (!commandExists("pacman")) {
            warn("pacman não encontrado — pulando instalação de pacotes.");
            warn("Instale manualmente: " + String.join(", ", PACKAGES));
            return;
        }

        List<String> missing = new ArrayList<>();
        for (String pkg : PACKAGES) {
            int code = execQuiet("pacman", "-Qi", pkg);
            if (code != 0) missing.add(pkg);
        }

        if (missing.isEmpty()) {
            success("Todos os pacotes já estão instalados.");
            return;
        }

        info("Pacotes a instalar: " + String.join(" ", missing));
        List<String> cmd = new ArrayList<>(List.of("sudo", "pacman", "-S", "--needed", "--noconfirm"));
        cmd.addAll(missing);
        int code = exec(dotfilesDir, cmd.toArray(new String[0]));
        if (code == 0) success("Pacotes instalados.");
        else error("Falha ao instalar pacotes (código " + code + ").");
    }

    // ── Etapa 2: fontes ───────────────────────────────────────────
    void installFonts() throws IOException, InterruptedException {
        header("Instalando fontes");
        Files.createDirectories(fontsDir);

        Path fontsSrc = dotfilesDir.resolve("hypr/Fonts");
        if (Files.isDirectory(fontsSrc)) {
            try (var stream = Files.walk(fontsSrc)) {
                for (Path font : (Iterable<Path>) stream::iterator) {
                    if (Files.isRegularFile(font)) {
                        String name = font.getFileName().toString().toLowerCase();
                        if ((name.endsWith(".ttf") || name.endsWith(".otf")) && !name.contains("jetbrains")) {
                            Files.copy(font, fontsDir.resolve(font.getFileName()), StandardCopyOption.REPLACE_EXISTING);
                            success("Font: " + font.getFileName());
                        }
                    }
                }
            }
        } else {
            warn("Pasta de fontes não encontrada em " + fontsSrc);
        }

        info("Baixando JetBrainsMono Nerd Font v3...");
        Path tmpZip = Files.createTempFile("JetBrainsMonoNerd", ".zip");
        boolean downloaded = downloadFile(NERD_FONT_URL, tmpZip);

        if (downloaded) {
            unzip(tmpZip, fontsDir);
            Files.deleteIfExists(tmpZip);
            success("JetBrainsMono Nerd Font v3 instalada.");
        } else {
            error("Falha ao baixar JetBrainsMono — verifique sua conexão.");
            warn("Usando a versão do repo como fallback.");
            if (Files.isDirectory(fontsSrc)) {
                try (var stream = Files.walk(fontsSrc)) {
                    for (Path font : (Iterable<Path>) stream::iterator) {
                        if (Files.isRegularFile(font) && font.getFileName().toString().toLowerCase().contains("jetbrains")) {
                            Files.copy(font, fontsDir.resolve(font.getFileName()), StandardCopyOption.REPLACE_EXISTING);
                        }
                    }
                }
            }
        }

        if (commandExists("fc-cache")) {
            execQuiet("fc-cache", "-fv", fontsDir.toString());
            success("Cache de fontes atualizado.");
        }
    }

    boolean downloadFile(String url, Path target) {
        try {
            HttpClient client = HttpClient.newBuilder()
                    .followRedirects(HttpClient.Redirect.ALWAYS)
                    .build();
            HttpRequest request = HttpRequest.newBuilder(URI.create(url)).GET().build();
            HttpResponse<Path> response = client.send(request, HttpResponse.BodyHandlers.ofFile(target));
            return response.statusCode() >= 200 && response.statusCode() < 300;
        } catch (Exception e) {
            return false;
        }
    }

    void unzip(Path zipFile, Path targetDir) throws IOException {
        try (ZipInputStream zis = new ZipInputStream(new BufferedInputStream(Files.newInputStream(zipFile)))) {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                Path outPath = targetDir.resolve(entry.getName()).normalize();
                if (!outPath.startsWith(targetDir)) continue; // proteção contra zip-slip
                if (entry.isDirectory()) {
                    Files.createDirectories(outPath);
                } else {
                    Files.createDirectories(outPath.getParent());
                    Files.copy(zis, outPath, StandardCopyOption.REPLACE_EXISTING);
                }
                zis.closeEntry();
            }
        }
    }

    // ── Etapa 3: tornar scripts executáveis ──────────────────────
    void makeScriptsExecutable() throws IOException {
        header("Tornando scripts executáveis (.sh, .lua, .py)");
        try (var stream = Files.walk(dotfilesDir)) {
            for (Path file : (Iterable<Path>) stream::iterator) {
                if (!Files.isRegularFile(file)) continue;
                String name = file.getFileName().toString();
                if (name.endsWith(".sh") || name.endsWith(".lua") || name.endsWith(".py")) {
                    makeExecutable(file);
                    success("chmod +x: " + name);
                }
            }
        }
    }

    void makeExecutable(Path file) throws IOException {
        try {
            Set<PosixFilePermission> perms = Files.getPosixFilePermissions(file);
            perms.add(PosixFilePermission.OWNER_EXECUTE);
            perms.add(PosixFilePermission.GROUP_EXECUTE);
            perms.add(PosixFilePermission.OTHERS_EXECUTE);
            Files.setPosixFilePermissions(file, perms);
        } catch (UnsupportedOperationException e) {
            file.toFile().setExecutable(true, false);
        }
    }

    // ── Etapa 4: symlinks + backup ────────────────────────────────
    void linkDotfiles() throws IOException {
        header("Linkando dotfiles");
        for (String name : CONFIG_DIRS) {
            Path src = dotfilesDir.resolve(name);
            Path dest = configDir.resolve(name);
            linkConfig(src, dest);
        }
    }

    void linkConfig(Path src, Path dest) throws IOException {
        if (!Files.exists(src)) {
            warn("Pulando (fonte não encontrada ainda): " + src);
            return;
        }
        backupConfig(dest);
        Files.createDirectories(dest.getParent());
        Files.deleteIfExists(dest);
        Files.createSymbolicLink(dest, src);
        success("Linked: " + dest.getFileName());
    }

    void backupConfig(Path target) throws IOException {
        if (Files.exists(target, LinkOption.NOFOLLOW_LINKS) && !Files.isSymbolicLink(target)) {
            Files.createDirectories(backupDir);
            Path dest = backupDir.resolve(target.getFileName());
            warn("Backup de " + target + " → " + dest);
            Files.move(target, dest, StandardCopyOption.REPLACE_EXISTING);
        } else if (Files.isSymbolicLink(target)) {
            Files.delete(target);
        }
    }

    // ── Etapa 4b: módulo QML M3Shapes (usado por StartupSplash/LockSurface) ──
    void installM3Shapes() throws IOException, InterruptedException {
        header("Instalando módulo QML M3Shapes (MaterialShape)");

        if (isM3ShapesAlreadyInstalled()) {
            success("M3Shapes já parece estar disponível no QML import path.");
            return;
        }

        if (!commandExists("cmake")) {
            warn("cmake não encontrado — pulando build do M3Shapes.");
            warn("StartupSplash.qml e LockSurface.qml vão falhar ao carregar até você instalar " +
                    "https://github.com/soramanew/m3shapes manualmente.");
            return;
        }

        Path cacheDir = homeDir.resolve(".cache/samdotfiles-installer");
        Path srcDir = cacheDir.resolve("m3shapes");
        Files.createDirectories(cacheDir);

        int code;
        if (Files.isDirectory(srcDir.resolve(".git"))) {
            info("Atualizando m3shapes já clonado em " + srcDir);
            code = exec(srcDir, "git", "pull", "--ff-only");
            if (code != 0) warn("Não foi possível atualizar via git pull, seguindo com o clone existente.");
        } else {
            info("Clonando " + M3SHAPES_REPO_URL + " ...");
            code = exec(cacheDir, "git", "clone", "--depth", "1", M3SHAPES_REPO_URL, srcDir.toString());
            if (code != 0) {
                error("Falha ao clonar o m3shapes. Pulando esta etapa.");
                return;
            }
        }

        Path installScript = srcDir.resolve("install.sh");
        if (Files.isRegularFile(installScript)) {
            info("install.sh encontrado no m3shapes, rodando com sudo...");
            makeExecutable(installScript);
            code = exec(srcDir, "sudo", "./install.sh");
            if (code == 0) {
                success("M3Shapes instalado via install.sh.");
                return;
            }
            warn("install.sh falhou (código " + code + "), tentando build manual via CMake...");
        }

        Path buildDir = srcDir.resolve("build");
        info("Configurando build (cmake -B build -DCMAKE_BUILD_TYPE=Release)...");
        code = exec(srcDir, "cmake", "-S", srcDir.toString(), "-B", buildDir.toString(),
                "-DCMAKE_BUILD_TYPE=Release");
        if (code != 0) {
            error("Falha ao configurar o CMake do m3shapes. Pulando esta etapa.");
            warn("Tente manualmente: cd " + srcDir + " && cmake -B build && cmake --build build && sudo cmake --install build");
            return;
        }

        info("Compilando m3shapes...");
        code = exec(srcDir, "cmake", "--build", buildDir.toString());
        if (code != 0) {
            error("Falha ao compilar o m3shapes. Pulando esta etapa.");
            return;
        }

        info("Instalando m3shapes (sudo cmake --install)...");
        code = exec(srcDir, "sudo", "cmake", "--install", buildDir.toString());
        if (code == 0) {
            success("M3Shapes instalado com sucesso no QML import path do Qt.");
        } else {
            error("Falha ao instalar o m3shapes (código " + code + ").");
            warn("Tente manualmente: sudo cmake --install " + buildDir);
        }
    }

    boolean isM3ShapesAlreadyInstalled() throws IOException, InterruptedException {
        // Pergunta ao Qt onde fica o QML import path e checa se M3Shapes já está lá.
        if (!commandExists("qmake6") && !commandExists("qtpaths6")) return false;
        String qmlPath = null;
        try {
            ProcessBuilder pb = commandExists("qtpaths6")
                    ? new ProcessBuilder("qtpaths6", "--query", "QT_INSTALL_QML")
                    : new ProcessBuilder("qmake6", "-query", "QT_INSTALL_QML");
            Process p = pb.start();
            try (BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()))) {
                qmlPath = r.readLine();
            }
            p.waitFor();
        } catch (IOException e) {
            return false;
        }
        if (qmlPath == null || qmlPath.isBlank()) return false;
        return Files.isDirectory(Paths.get(qmlPath.trim(), "M3Shapes"));
    }

    // ── Etapa 5: wallpapers + tema inicial ────────────────────────
    void setupWallpapersAndTheme() throws IOException, InterruptedException {
        header("Configuração de Wallpapers & Tema Inicial");
        Files.createDirectories(wallpaperDir);
        info("Diretório de wallpapers criado/verificado em: " + wallpaperDir);

        Path themeScript = configDir.resolve("scripts/gerar_tema.sh");
        if (Files.isRegularFile(themeScript)) {
            info("Inicializando geração da paleta de cores...");
            int code = exec(dotfilesDir, "bash", themeScript.toString());
            if (code != 0) {
                warn("Adicione pelo menos uma imagem em " + wallpaperDir + " para o tema ser gerado automaticamente.");
            }
        }
    }

    // ── Utilitários de processo ────────────────────────────────────
    boolean commandExists(String cmd) throws IOException, InterruptedException {
        return execQuiet("bash", "-c", "command -v " + cmd) == 0;
    }

    int execQuiet(String... cmd) throws IOException, InterruptedException {
        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.redirectOutput(ProcessBuilder.Redirect.DISCARD);
        pb.redirectError(ProcessBuilder.Redirect.DISCARD);
        Process p = pb.start();
        return p.waitFor();
    }

    int exec(Path cwd, String... cmd) throws IOException, InterruptedException {
        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.directory(cwd.toFile());
        pb.inheritIO();
        Process p = pb.start();
        return p.waitFor();
    }
}
