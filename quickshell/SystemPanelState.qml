pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// ============================================================
// SystemPanelState.qml — camada de ESTADO (item 12/15): quais modulos
// estao ativos, em que ordem, quantas colunas. Persiste em
// Quickshell.stateDir (diretorio oficial pra esse tipo de dado —
// documentado, nao e' um caminho inventado na mao).
//
// Raiz e' "Scope" (nao QtObject) porque precisamos aninhar um FileView
// como filho — QtObject puro nao tem propriedade padrao pra receber
// elemento filho declarado (so' segura property/function soltos).
// Mesmo tipo que o LockContext.qml ja usa hoje pra aninhar o
// PamContext, e aquele ja roda sem erro.
//
// A logica de hide/show/move foi simulada e testada em Python antes
// de virar QML (inclusive os casos de borda: mover o primeiro item
// pra esquerda, o ultimo pra direita, esconder/mostrar tudo).
// ============================================================
Scope {
    id: root

    // Edicao e' estado de SESSAO, nao precisa persistir — sempre
    // comeca em modo normal quando o painel abre.
    property bool editMode: false
    function toggleEditMode() { editMode = !editMode }

    property alias order: adapter.order
    property alias hidden: adapter.hidden
    property alias gridColumns: adapter.gridColumns

    function isHidden(id) {
        return root.hidden.indexOf(id) !== -1;
    }

    function hide(id) {
        if (!root.isHidden(id)) {
            const h = root.hidden.slice();
            h.push(id);
            root.hidden = h;
        }
        const o = root.order.slice();
        const i = o.indexOf(id);
        if (i !== -1) {
            o.splice(i, 1);
            root.order = o;
        }
    }

    function show(id) {
        const h = root.hidden.slice();
        const i = h.indexOf(id);
        if (i !== -1) {
            h.splice(i, 1);
            root.hidden = h;
        }
        if (root.order.indexOf(id) === -1) {
            const o = root.order.slice();
            o.push(id);
            root.order = o;
        }
    }

    function moveLeft(id) { root._move(id, -1) }
    function moveRight(id) { root._move(id, 1) }

    function _move(id, delta) {
        const o = root.order.slice();
        const i = o.indexOf(id);
        const j = i + delta;
        if (i === -1 || j < 0 || j >= o.length) return;
        const tmp = o[i];
        o[i] = o[j];
        o[j] = tmp;
        root.order = o;
    }

    // Reordena pra um indice arbitrario (usado pelo drag-and-drop —
    // moveLeft/moveRight continuam existindo pros botoes de seta).
    // Testado em Python antes disso, inclusive indice fora do range
    // (gruda na borda em vez de quebrar) e mover pra mesma posicao
    // (vira no-op).
    function reorderTo(id, targetIndex) {
        const o = root.order.slice();
        const i = o.indexOf(id);
        if (i === -1) return;
        o.splice(i, 1);
        const clamped = Math.max(0, Math.min(targetIndex, o.length));
        o.splice(clamped, 0, id);
        root.order = o;
    }

    // ---------------- tamanho dos modulos (item novo: "resizeable") ---
    // Guardado por id, paralelo e DESACOPLADO da ordem de proposito —
    // reordenar nao pode bagunçar tamanho nenhum. Testado em Python:
    // sobrescrever nao duplica, tamanho sobrevive a reorder.
    property alias sizedIds: adapter.sizedIds
    property alias sizeValues: adapter.sizeValues

    readonly property var sizeOptions: ["1x1", "2x1", "2x2"]

    function sizeFor(id) {
        const i = root.sizedIds.indexOf(id);
        return i !== -1 ? root.sizeValues[i] : "1x1";
    }

    function setSize(id, size) {
        const ids = root.sizedIds.slice();
        const vals = root.sizeValues.slice();
        const i = ids.indexOf(id);
        if (i !== -1) {
            vals[i] = size;
        } else {
            ids.push(id);
            vals.push(size);
        }
        root.sizedIds = ids;
        root.sizeValues = vals;
    }

    // Cicla pro proximo tamanho da lista (usado pelo botao de resize)
    function cycleSize(id) {
        const cur = root.sizeFor(id);
        const idx = root.sizeOptions.indexOf(cur);
        const next = root.sizeOptions[(idx + 1) % root.sizeOptions.length];
        root.setSize(id, next);
    }

    // "1x1" -> {cols:1, rows:1}, com fallback seguro pra valor invalido
    function spanFor(id) {
        const size = root.sizeFor(id);
        switch (size) {
            case "2x1": return { cols: 2, rows: 1 };
            case "2x2": return { cols: 2, rows: 2 };
            default:    return { cols: 1, rows: 1 };
        }
    }

    function resetToDefaults() {
        root.order = SystemPanelModules.defaultOrder.slice();
        root.hidden = [];
        root.gridColumns = 4;
        root.sizedIds = [];
        root.sizeValues = [];
    }

    // Listas ja resolvidas contra o registro — e' isso que a UI consome,
    // nunca ids crus.
    readonly property var visibleModules: root.order
        .filter(id => !root.isHidden(id))
        .map(id => SystemPanelModules.byId(id))
        .filter(m => m !== null)

    readonly property var availableToAdd: root.hidden
        .map(id => SystemPanelModules.byId(id))
        .filter(m => m !== null)

    FileView {
        id: fileView
        path: Quickshell.stateDir + "/system-panel.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            // Arquivo novo/vazio: popula com a ordem padrao na primeira
            // vez, senao o painel abriria sem nenhum modulo.
            if (adapter.order.length === 0 && adapter.hidden.length === 0) {
                adapter.order = SystemPanelModules.defaultOrder.slice();
            }
        }
        onLoadFailed: error => {
            adapter.order = SystemPanelModules.defaultOrder.slice();
        }

        JsonAdapter {
            id: adapter
            property list<string> order: []
            property list<string> hidden: []
            property int gridColumns: 4
            property list<string> sizedIds: []
            property list<string> sizeValues: []
        }
    }
}
