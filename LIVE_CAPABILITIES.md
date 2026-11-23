# Live Capabilities Matrix — L4NE Training v1.2.0 (Ελεγμένο 23/11/2026)

Στόχος: iPhone (iOS 17+) & macOS (macOS 14+) με κοινό πυρήνα Rust (`l4ne-core` v1.2.0) και προαιρετική σύνδεση με Apple HealthKit / Apple Watch. Όλοι οι υπολογισμοί είναι 100% ντετερμινιστικοί χωρίς AI/LLM ή cloud backend.

| Λειτουργία / Ένδειξη | Προέλευση / Μαθηματικός Υπολογισμός | Όριο & Συμπεριφορά |
| :--- | :--- | :--- |
| **Ανάπτυξη Σετ & Πυραμίδων (`ExpectedRepSlot`)** | Ντετερμινιστική ανάπτυξη `rounds × blocks` σε ακολουθία `1..=N` slots (`engine::expand_template_slots`) | Έως 500 επαναλήψεις ανά template. Υποστηρίζει ομοιογενή σετ (`8×50m`), πυραμίδες (`50-100-150-100-50m`) και σύνθετους κύκλους (`4×[2×50+100]`). |
| **Ιστορική Ακεραιότητα (`TemplateVersion`)** | Κανονικό SHA-256 `protocol_hash` επί αθλήματος, πισίνας, κύκλων, εξοπλισμού, αποστάσεων, στυλ και διαλείμματος | Κάθε αλλαγή φυσιολογικής παραμέτρου δημιουργεί νέα έκδοση (`v2`, `v3`…). Τα παλιά sessions παραμένουν αμετάβλητα στην έκδοση εκτέλεσής τους. |
| **Athletic Centisecond Numpad** | Positional centisecond parser (`MMSScc` / `SScc` → ακέραια `duration_ms: i64`) | Πληκτρολόγηση χωρίς τελείες (`3240` → `32.40s`, `10855` → `1:08.55`). Απορρίπτει δευτερόλεπτα `>= 60` όταν υπάρχουν λεπτά. |
| **Live Poolside Stopwatch (v1.1/v1.2)** | Μονοτονικό ρολόι συστήματος (`ProcessInfo.processInfo.systemUptime`) + Rust tick evaluator | Debounce `>= 0.80s` σε κάθε πάτημα για προστασία από σταγόνες νερού στην οθόνη. Υποστηρίζει ενδιάμεσα `LAP SPLIT` εντός της επανάληψης. |
| **Πραγματικό Διάλειμμα σε Send-Off ($R_i$)** | $R_i = \max(0, S - t_i)$ όπου $S$ ο κύκλος αναχώρησης και $t_i$ ο χρόνος της επανάληψης | Αν $t_i > S$, το Live Timer εμφανίζει `sendoff_overrun` και μηδενικό υπόλοιπο διαλείμματος. |
| **Σταθμισμένος Ρυθμός / 100m ($P_{100}$)** | $P_{100} = \frac{\sum t_i}{\sum d_i} \times 100$ σε ακέραια ms ανά 100m | Λειτουργεί τόσο σε ομοιογενή σετ όσο και σε πυραμίδες διαφορετικών αποστάσεων. |
| **Δείκτης Συνέπειας ($\text{CV}\%$)** | $\text{CV} = (\sigma / \mu) \times 100$ (επί χρόνων σε ομοιογενή σετ, επί ρυθμού `/100m` σε πυραμίδες) | Απαιτεί $\ge 2$ έγκυρες (μη-skipped) επαναλήψεις. `0.00%` = απόλυτη σταθερότητα. |
| **Δείκτης Κόπωσης ($\text{Fatigue}\%$)** | $\frac{P_{\text{2nd\_half}} - P_{\text{1st\_half}}}{P_{\text{1st\_half}}} \times 100$ | Αρνητική τιμή ($< 0\%$) υποδηλώνει **Negative Split** (ταχύτερο δεύτερο μισό). |
| **SWOLF Κολύμβησης** | $\text{round}(t_i / 1000) + \text{stroke\_count}_i$ | Υπολογίζεται μόνο όταν ο αθλητής καταχωρίσει `stroke_count > 0`. |
| **Gym Tonnage & Epley 1RM** | $\text{Tonnage} = \sum (w_i \times r_i)$, $1\text{RM} = w_i \times (1 + r_i / 30)$ | Για templates με `record_kind = weight_reps`. Θετική βελτίωση = αύξηση όγκου/βάρους. |
| **Field Άλματα / Ρίψεις** | $\text{Best Attempt} = \max(m_i)$ σε μέτρα | Για templates με `record_kind = distance_attempt`. Αγνοεί άκυρες (`is_skipped`) προσπάθειες. |
| **HealthKit Workout Matcher** | Ντετερμινιστικό σκορ συμβατότητας (Άθλημα `+50`, Πισίνα `+25`/`-20`, Υπόλοιπος όγκος `+25`/`-30`) | Κολυμβητικά workouts του Apple Watch ταιριάζουν τόσο με `Swimming` όσο και με `Finswimming` templates. |
| **Watch Lap Auto-Prefill (v1.2)** | Αυτόματη αντιστοίχιση `HKWorkoutEvent` laps στα slots του template (`prefill_reps_from_workout_laps`) | Σε πυραμίδες (π.χ. 100m ή 150m σε 50άρα πισίνα) αθροίζει 2 ή 3 διαδοχικά 50άρια και κρατά τα επιμέρους splits στο `splits_ms`. |
| **HealthKit Export (`HKWorkout` Write)** | Εγγραφή μέσω `HKWorkoutBuilder` με `HKMetadataKeyExternalUUID = L4NE-SESSION-<id>` | Αποθηκεύει το `exported_external_uuid` στη SQLite ώστε να αποτρέπεται διπλή εξαγωγή του ίδιου session. |
| **Health Context (Ύπνος, HRV, RHR, VO₂ Max)** | Χρονική σύζευξη ημερομηνίας (`YYYY-MM-DD`) μεταξύ `sessions` και `daily_health_snapshots` | Παρουσιάζει αποκλειστικά **παρατηρησιακή συσχέτιση** (observational correlation) και ποτέ αιτιότητα. |

Επιτυχής εκτέλεση του `./scripts/verify.sh` επαληθεύει τον Rust πυρήνα, τη SQLite v3, τη γέφυρα FFI και το compile του SwiftUI app, αλλά δεν υποκαθιστά τη φυσική δοκιμή στην πισίνα ([docs/Physical-acceptance.md](docs/Physical-acceptance.md)).
