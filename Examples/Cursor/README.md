# Plugin Cursor (esempio completo)

Una **sola cartella** = un plugin. Niente file sparsi fuori da qui.

```text
Cursor/
  README.md        ← questo file (documentazione)
  manifest.json    ← menu + regole (obbligatorio)
  run.sh           ← logica (eseguibile)
```

## Cosa fa

Dal menu contestuale su file/cartelle selezionati:

| Voce | Azione |
|------|--------|
| Apri chat nella cartella | Nuova finestra Cursor sulla cartella (o sul parent del file) |
| Agent nel Terminale… | `cursor agent` in Terminal con `--workspace` |
| Apri → … | Apri / Classic / finestra corrente / aggiungi cartella |
| Confronta due file… | `cursor -d` (servono 2 file) |
| Copia comando CLI cursor | Mette in clipboard un comando pronto |

Requisito esterno: CLI `cursor` nel PATH (da Cursor → Command Palette → Install `cursor` command).

## Installazione in Mac Explorer

1. Menu **Plugin → Installa plugin…** e scegli questa cartella `Cursor`  
   **oppure** copia l’intera cartella in:
   `~/Library/Application Support/Mac Explorer/Plugins/Cursor`
2. `chmod +x run.sh` (l’installazione da menu lo fa già)
3. Tasto destro su un file/cartella → voce **Cursor**

Le modifiche a `manifest.json` / `run.sh` nella cartella Plugins si **ricaricano a caldo**.

## Contratto di esecuzione

```text
./run.sh <action> /percorso/assoluto [...]
```

`action` è il campo `"action"` del menu (es. `chat`, `agent`, `diff`).
