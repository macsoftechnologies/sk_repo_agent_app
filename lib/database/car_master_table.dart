class CarMasterTable {
  static const tableName = "car_master";

  static const createTable = '''
  CREATE TABLE $tableName (
    car_id INTEGER PRIMARY KEY AUTOINCREMENT,
    backend_car_id INTEGER UNIQUE,    -- ID from server
    batch_number TEXT,
   reg_no TEXT NOT NULL UNIQUE COLLATE NOCASE,  -- 👈 ADD COLLATE NOCASE
    car_make TEXT,
    car_modal TEXT,
    status TEXT DEFAULT 'Unverified',
    assigned_agent_name TEXT,
    assigned_agent_id INTEGER,
    gps_location TEXT,
    location_details TEXT,
    photo TEXT,
    notes TEXT,
    created_at TEXT,
    updated_at TEXT,
    created_by INTEGER,
    updated_by INTEGER,
    mode TEXT DEFAULT 'online',        -- 'online' or 'offline'
    sync_status TEXT DEFAULT 'synced', -- 'synced', 'pending', 'failed'
    last_sync_time TEXT
  )
  ''';

  static const addSyncColumns = '''
  ALTER TABLE $tableName 
  ADD COLUMN mode TEXT DEFAULT 'online',
  ADD COLUMN sync_status TEXT DEFAULT 'synced',
  ADD COLUMN last_sync_time TEXT,
  ADD COLUMN backend_car_id INTEGER UNIQUE
  ''';
}