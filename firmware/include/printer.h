struct Printer {
    // TODO
}

Printer printer_init();

// Returns: true on success, false on failure (e.g. offline)
bool printer_fetchAndPrintMessages(Printer &printer);