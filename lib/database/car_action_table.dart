class CarActionTable {
  static const tableName = "car_actions";

  static const createTable = '''
  CREATE TABLE $tableName (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    backend_action_id INTEGER,
    agent_id INTEGER,
    reg_no TEXT NOT NULL COLLATE NOCASE,  -- 👈 REMOVED UNIQUE
    action_type TEXT DEFAULT 'search',
    car_make TEXT,
    car_modal TEXT,
    status TEXT,
    found INTEGER DEFAULT 0,
    gps_location TEXT,
    location_details TEXT,
    notes TEXT,
    photo TEXT,
    car_id INTEGER,
    searched_at TEXT,
    created_at TEXT,
    updated_at TEXT,
    assigned_agent_id INTEGER,
    assigned_agent_name TEXT,
    created_by INTEGER,
    mode TEXT DEFAULT 'offline',         -- 👈 Changed default to offline
    sync_status TEXT DEFAULT 'pending',  -- 👈 Local actions start as pending
    sync_attempts INTEGER DEFAULT 0,
    last_sync_time TEXT
  )
  ''';

  // Create index for faster searches (optional but recommended)
  static const createIndex = '''
  CREATE INDEX idx_car_actions_reg_no ON $tableName (reg_no);
  CREATE INDEX idx_car_actions_searched_at ON $tableName (searched_at DESC);
  ''';
}