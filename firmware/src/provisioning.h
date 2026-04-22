// =============================================================================
// provisioning.h — SoftAP + captive-portal provisioning
// =============================================================================
// Usage from the state machine:
//
//   onEntry(Provisioning):   provisioning_begin();
//   loop while in state:     provisioning_loop();
//                            if (provisioning_isComplete()) transition out;
//   onExit(Provisioning):    provisioning_end();
//
// The module handles AP bring-up, a small HTTP server, credential validation
// (by test-connecting before committing to NVS), and NVS persistence.
// =============================================================================
#pragma once

void provisioning_begin();
void provisioning_loop();
void provisioning_end();
bool provisioning_isComplete();
