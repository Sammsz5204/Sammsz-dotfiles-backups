// ============================================================
// shell.qml — ponto de entrada. So instancia a Bar em cada monitor
// conectado (equivalente ao "output": ["HDMI-A-3","VGA-1"] do waybar,
// so que reativo — nao precisa listar nome de monitor na mao).
// Padrao confirmado na doc oficial: Scope + Variants + PanelWindow.
// ============================================================
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        Bar {
            modelData: modelData
        }
    }

    // ============================================================
    // Lockscreen — comeca DESTRAVADO (locked: false). So trava quando
    // chamado via IPC (bind do hyprland.lua) ou "qs -c quickshell ipc
    // call lock lock" na mao. Nao troca a hyprlock ainda — os dois
    // ficam disponiveis em paralelo ate isso rodar estavel por um tempo.
    //
    // Quem solta o lock de verdade e' o LockSurface, via closed() —
    // so' depois de tocar a animacao de saida. lockContext.unlocked
    // so' avisa "senha certa", nao desmonta nada sozinho.
    // ============================================================
    LockContext {
        id: lockContext
        
        // Twin js add this property to hold the screenshot path
        property string bgSource: ""
    }

    // Process to silently take the screenshot using grim
    Process {
        id: grimProc
        command: ["grim", "/tmp/qs_lock_bg.png"]
        
        onExited: {
            // Update the image source and bust the cache so Qt reloads it
            lockContext.bgSource = "file:///tmp/qs_lock_bg.png?v=" + Date.now();
            // ONLY lock the screen after the screenshot is successfully saved
            lock.locked = true;
        }
    }

    WlSessionLock {
        id: lock
        locked: false
        
        WlSessionLockSurface {
            color: "transparent"

            LockSurface {
                color: "transparent"
                anchors.fill: parent
                context: lockContext
                onClosed: lock.locked = false
            }
        }
    }

    IpcHandler {
        target: "lock"

        function engage(): void {
            lockContext.currentText = "";
            lockContext.showFailure = false;
            // Run grim instead of locking right away
            grimProc.running = true;
        }

        function disengage(): void {
            lock.locked = false;
        }

        function isLocked(): bool {
            return lock.locked;
        }
    }
}
