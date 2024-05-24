CREATE SCHEMA IF NOT EXISTS missionbase;
SET search_path TO missionbase;

CREATE TABLE IF NOT EXISTS missionbase.users (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER DEFAULT NULL,
    username VARCHAR(40) NOT NULL,
    user_pass VARCHAR(255) NOT NULL,
    api_salt VARCHAR(255) DEFAULT NULL,
    email VARCHAR(255) NOT NULL,
    user_role ENUM('user', 'administrator', 'canceled') DEFAULT 'user',
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- trigger to update updated_datetime
CREATE OR REPLACE FUNCTION missionbase.update_updated_datetime() RETURNS TRIGGER AS $$ BEGIN NEW.updated_datetime = NOW();
RETURN NEW;
END;

CREATE TRIGGER users_updated_datetime BEFORE
UPDATE ON missionbase.users FOR EACH ROW EXECUTE FUNCTION missionbase.update_updated_datetime();

CREATE TABLE IF NOT EXISTS missionbase.meta_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL
) COMMENT 'Type information to help the ui know how to render the meta value. Input validation if needed is required in the API.';

CREATE TABLE IF NOT EXISTS missionbase.user_meta(
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    meta_type INTEGER NOT NULL,
    meta_key VARCHAR(255) NOT NULL,
    meta_value TEXT DEFAULT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
ADD CONSTRAINT fk_user_meta_user_id FOREIGN KEY (user_id) REFERENCES missionbase.users(id) ON DELETE CASCADE
ADD CONSTRAINT fk_user_meta_meta_type FOREIGN KEY (meta_type) REFERENCES missionbase.meta_types(id) ON DELETE RESTRICT;

CREATE TRIGGER user_meta_updated_datetime BEFORE
UPDATE ON missionbase.user_meta FOR EACH ROW EXECUTE FUNCTION missionbase.update_updated_datetime();

CREATE TABLE IF NOT EXISTS missionbase.countries (
    code INTEGER PRIMARY KEY COMMENT 'ISO 3166-1 numeric code',
    alpha2 VARCHAR(2) NOT NULL COMMENT 'ISO 3166-1 alpha-2 code',
    alpha3 VARCHAR(3) NOT NULL COMMENT 'ISO 3166-1 alpha-3 code',
    name VARCHAR(255) NOT NULL,
) COMMENT 'https://www.iban.com/country-codes';

CREATE INDEX IF NOT EXISTS idx_countries_alpha2 ON missionbase.countries(alpha2);

CREATE TABLE IF NOT EXISTS missionbase.states (
    id SERIAL PRIMARY KEY,
    country_code VARCHAR(2) NOT NULL COMMENT 'ISO 3166-1 alpha-2 code',
    name VARCHAR(255) NOT NULL,
    code VARCHAR(2) DEFAULT NULL COMMENT 'ISO 3166-2 code',
    abbreviation VARCHAR(10) DEFAULT NULL
)
ADD CONSTRAINT fk_states_country_code FOREIGN KEY (country_code) REFERENCES missionbase.countries(alpha2) ON DELETE RESTRICT;

CREATE TABLE IF NOT EXISTS missionbase.locations (
    id SERIAL PRIMARY KEY,
    coordinates POINT NOT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS missionbase.acl_list (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    action ENUM('view', 'moderate', 'admin') DEFAULT 'view',
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
ADD CONSTRAINT fk_acl_list_user_id FOREIGN KEY (user_id) REFERENCES missionbase.users(id) ON DELETE CASCADE;

CREATE OR REPLACE FUNCTION missionbase.delete_acl_list_item() RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM missionbase.acl_list WHERE id = OLD.acl_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS missionbase.addresses (
    id SERIAL PRIMARY KEY,
    line_1 VARCHAR(255) NOT NULL,
    line_2 VARCHAR(255) DEFAULT NULL,
    city VARCHAR(255) NOT NULL,
    state INTEGER NOT NULL,
    post_code VARCHAR(10) NOT NULL,
    location INTEGER DEFAULT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
ADD CONSTRAINT fk_addresses_state FOREIGN KEY (state) REFERENCES missionbase.states(id) ON DELETE RESTRICT
ADD CONSTRAINT fk_addresses_location FOREIGN KEY (location) REFERENCES missionbase.locations(id) ON DELETE RESTRICT;

CREATE TRIGGER addresses BEFORE
UPDATE ON missionbase.addresses FOR EACH ROW EXECUTE FUNCTION missionbase.update_updated_datetime();

CREATE TABLE IF NOT EXISTS missionbase.address_acl (
    id SERIAL PRIMARY KEY,
    address_id INTEGER NOT NULL,
    acl_id INTEGER NOT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigner_id INTEGER DEFAULT NULL
)
ADD CONSTRAINT fk_address_acl_address_id FOREIGN KEY (address_id) REFERENCES missionbase.addresses(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_address_acl_acl_id FOREIGN KEY (acl_id) REFERENCES missionbase.acl_list(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_address_acl_assigner_id FOREIGN KEY (assigner_id) REFERENCES missionbase.users(id) ON DELETE SET NULL;

CREATE TRIGGER delete_address_acl_list_item AFTER DELETE ON missionbase.address_acl FOR EACH ROW EXECUTE FUNCTION missionbase.delete_acl_list_item();

CREATE TABLE IF NOT EXISTS missionbase.contact_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT DEFAULT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS missionbase.contacts (
    id SERIAL PRIMARY KEY,
    guid UUID DEFAULT uuid_generate_v4(),
    contact_type INTEGER NOT NULL,
    org_name VARCHAR(255) DEFAULT NULL,
    prefix VARCHAR(200) DEFAULT NULL,
    first_name VARCHAR(255) DEFAULT NULL,
    middle_name VARCHAR(255) DEFAULT NULL,
    last_name VARCHAR(255) DEFAULT NULL,
    suffix VARCHAR(200) DEFAULT NULL,
    name TEXT GENERATED ALWAYS AS (
        CASE
            WHEN org_name IS NOT NULL THEN org_name
            ELSE CONCAT_WS(' ', prefix, first_name, middle_name, last_name, suffix)
        END
    ) STORED;
    creator_id INTEGER DEFAULT NULL,
    location INTEGER DEFAULT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
ADD CONSTRAINT fk_contacts_creator_id FOREIGN KEY (creator_id) REFERENCES missionbase.users(id) ON DELETE SET NULL,
ADD CONSTRAINT fk_contacts_contact_type FOREIGN KEY (contact_type) REFERENCES missionbase.contact_types(id) ON DELETE RESTRICT
ADD CONSTRAINT fk_contacts_location FOREIGN KEY (location) REFERENCES missionbase.locations(id) ON DELETE RESTRICT;

ALTER TABLE missionbase.users ADD CONSTRAINT fk_users_contact_id FOREIGN KEY (contact_id) REFERENCES missionbase.contacts(id) ON DELETE RESTRICT;

CREATE TRIGGER contacts BEFORE
UPDATE ON missionbase.contacts FOR EACH ROW EXECUTE FUNCTION missionbase.update_updated_datetime();

CREATE TABLE IF NOT EXISTS missionbase.contact_acl (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER NOT NULL,
    acl_id INTEGER NOT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigner_id INTEGER DEFAULT NULL
)
ADD CONSTRAINT fk_contact_acl_contact_id FOREIGN KEY (contact_id) REFERENCES missionbase.contacts(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_contact_acl_acl_id FOREIGN KEY (acl_id) REFERENCES missionbase.acl_list(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_contact_acl_assigner_id FOREIGN KEY (assigner_id) REFERENCES missionbase.users(id) ON DELETE SET NULL;

CREATE TRIGGER delete_contact_acl_list_item AFTER DELETE ON missionbase.contact_acl FOR EACH ROW EXECUTE FUNCTION missionbase.delete_acl_list_item();

CREATE TABLE IF NOT EXISTS missionbase.contact_relation_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL
);

CREATE TABLE IF NOT EXISTS missionbase.contact_relationships (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER NOT NULL,
    related_contact_id INTEGER NOT NULL,
    relation_type INTEGER NOT NULL,
    assigner_id INTEGER DEFAULT NULL,
    primary BOOLEAN DEFAULT FALSE,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
ADD CONSTRAINT fk_contact_relationships_contact_id FOREIGN KEY (contact_id) REFERENCES missionbase.contacts(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_contact_relationships_related_contact_id FOREIGN KEY (related_contact_id) REFERENCES missionbase.contacts(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_contact_relationships_relation_type FOREIGN KEY (relation_type) REFERENCES missionbase.contact_relation_types(id) ON DELETE RESTRICT
ADD CONSTRAINT fk_contact_relationships_assigner_id FOREIGN KEY (assigner_id) REFERENCES missionbase.users(id) ON DELETE SET NULL;

CREATE TRIGGER contact_relationships BEFORE
UPDATE ON missionbase.contact_relationships FOR EACH ROW EXECUTE FUNCTION missionbase.update_updated_datetime();

-- Only one primary relationship per contact per relation type
CREATE UNIQUE INDEX idx_contact_relationships_primary ON missionbase.contact_relationships(contact_id, relation_type, primary) WHERE primary;

CREATE TABLE IF NOT EXISTS missionbase.contact_meta (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER NOT NULL,
    meta_type INTEGER NOT NULL,
    meta_key VARCHAR(255) NOT NULL,
    meta_value TEXT DEFAULT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
ADD CONSTRAINT fk_contact_meta_contact_id FOREIGN KEY (contact_id) REFERENCES missionbase.contacts(id) ON DELETE CASCADE
ADD CONSTRAINT fk_contact_meta_meta_type FOREIGN KEY (meta_type) REFERENCES missionbase.meta_types(id) ON DELETE RESTRICT;

CREATE TABLE IF NOT EXISTS missionbase.contact_meta_acl (
    id SERIAL PRIMARY KEY,
    contact_meta_id INTEGER NOT NULL,
    acl_id INTEGER NOT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigner_id INTEGER DEFAULT NULL
)
ADD CONSTRAINT fk_contact_meta_acl_contact_meta_id FOREIGN KEY (contact_meta_id) REFERENCES missionbase.contact_meta(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_contact_meta_acl_acl_id FOREIGN KEY (acl_id) REFERENCES missionbase.acl_list(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_contact_meta_acl_assigner_id FOREIGN KEY (assigner_id) REFERENCES missionbase.users(id) ON DELETE SET NULL;

CREATE TRIGGER delete_contact_meta_acl_list_item AFTER DELETE ON missionbase.contact_meta_acl FOR EACH ROW EXECUTE FUNCTION missionbase.delete_acl_list_item();

CREATE TABLE IF NOT EXISTS missionbase.address_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS missionbase.contact_addresses (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER NOT NULL,
    address_id INTEGER NOT NULL,
    address_type INTEGER NOT NULL,
    priority INTEGER DEFAULT 1 COMMENT '1 is highest priority',
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
ADD CONSTRAINT fk_contact_addresses_contact_id FOREIGN KEY (contact_id) REFERENCES missionbase.contacts(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_contact_addresses_address_id FOREIGN KEY (address_id) REFERENCES missionbase.addresses(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_contact_addresses_address_type FOREIGN KEY (address_type) REFERENCES missionbase.address_types(id) ON DELETE RESTRICT;

CREATE TRIGGER contact_addresses BEFORE
UPDATE ON missionbase.contact_addresses FOR EACH ROW EXECUTE FUNCTION missionbase.update_updated_datetime();

CREATE TABLE IF NOT EXISTS missionbase.contact_address_acl (
    id SERIAL PRIMARY KEY,
    contact_address_id INTEGER NOT NULL,
    acl_id INTEGER NOT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigner_id INTEGER DEFAULT NULL
)
ADD CONSTRAINT fk_contact_address_acl_contact_address_id FOREIGN KEY (contact_address_id) REFERENCES missionbase.contact_addresses(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_contact_address_acl_acl_id FOREIGN KEY (acl_id) REFERENCES missionbase.acl_list(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_contact_address_acl_assigner_id FOREIGN KEY (assigner_id) REFERENCES missionbase.users(id) ON DELETE SET NULL;

CREATE TRIGGER delete_contact_address_acl_list_item AFTER DELETE ON missionbase.contact_address_acl FOR EACH ROW EXECUTE FUNCTION missionbase.delete_acl_list_item();

CREATE TABLE IF NOT EXISTS missionbase.login_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP HTTP_USER_AGENT VARCHAR(300) DEFAULT NULL,
    REMOTE_ADDR VARCHAR(45) DEFAULT NULL COMMENT 'IP address may not be accurate due to proxies, VPNs, etc.',
    REQUEST_URI VARCHAR(8000) DEFAULT NULL,
    jwtid VARCHAR(32) DEFAULT NULL,
)
ADD CONSTRAINT fk_login_history_user_id FOREIGN KEY (user_id) REFERENCES missionbase.users(id) ON DELETE NO ACTION;

CREATE TABLE IF NOT EXISTS missionbase.groups (
    id SERIAL PRIMARY KEY,
    slug VARCHAR(25) DEFAULT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT DEFAULT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    contact_id INTEGER DEFAULT NULL,
    public BOOLEAN DEFAULT FALSE
)
ADD CONSTRAINT fk_groups_contact_id FOREIGN KEY (contact_id) REFERENCES missionbase.contacts(id) ON DELETE RESTRICT;

CREATE TRIGGER groups_updated_datetime BEFORE
UPDATE ON missionbase.groups FOR EACH ROW EXECUTE FUNCTION missionbase.update_updated_datetime();

CREATE TABLE IF NOT EXISTS missionbase.group_users (
    id SERIAL PRIMARY KEY,
    group_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    access_level INTEGER DEFAULT 1,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
ADD CONSTRAINT fk_group_users_group_id FOREIGN KEY (group_id) REFERENCES missionbase.groups(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_group_users_user_id FOREIGN KEY (user_id) REFERENCES missionbase.users(id) ON DELETE CASCADE;

CREATE TRIGGER group_users_updated_datetime BEFORE
UPDATE ON missionbase.group_users FOR EACH ROW EXECUTE FUNCTION missionbase.update_updated_datetime();

CREATE TABLE IF NOT EXISTS missionbase.actions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS missionbase.group_rights (
    id SERIAL PRIMARY KEY,
    group_id INTEGER NOT NULL,
    access_level INTEGER NOT NULL,
    action INTEGER NOT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
ADD CONSTRAINT fk_group_rights_group_id FOREIGN KEY (group_id) REFERENCES missionbase.groups(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_group_rights_action FOREIGN KEY (action) REFERENCES missionbase.actions(id) ON DELETE CASCADE,
ADD CONSTRAINT group_rights_unique_group_action UNIQUE (group_id, action);

CREATE TRIGGER group_rights_updated_datetime BEFORE
UPDATE ON missionbase.group_rights FOR EACH ROW EXECUTE FUNCTION missionbase.update_updated_datetime();

CREATE TABLE IF NOT EXISTS missionbase.tags (
    id SERIAL PRIMARY KEY,
    slug VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT NULL,
    ttl INTERVAL DEFAULT NULL,
    color VARCHAR(6) DEFAULT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    public BOOLEAN DEFAULT FALSE
);

CREATE TRIGGER tags_updated_datetime BEFORE
UPDATE ON missionbase.tags FOR EACH ROW EXECUTE FUNCTION missionbase.update_updated_datetime();

CREATE TABLE IF NOT EXISTS missionbase.tag_acl (
    id SERIAL PRIMARY KEY,
    tag_id INTEGER NOT NULL,
    acl_id INTEGER NOT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigner_id INTEGER DEFAULT NULL
)
ADD CONSTRAINT fk_tag_acl_tag_id FOREIGN KEY (tag_id) REFERENCES missionbase.tags(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_tag_acl_acl_id FOREIGN KEY (acl_id) REFERENCES missionbase.acl_list(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_tag_acl_assigner_id FOREIGN KEY (assigner_id) REFERENCES missionbase.users(id) ON DELETE SET NULL;

CREATE TRIGGER delete_tag_acl_list_item AFTER DELETE ON missionbase.tag_acl FOR EACH ROW EXECUTE FUNCTION missionbase.delete_acl_list_item();

CREATE TABLE IF NOT EXISTS missionbase.tag_groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT NULL,
    public BOOLEAN DEFAULT FALSE,
);

CREATE TABLE IF NOT EXISTS missionbase.tag_group_acl (
    id SERIAL PRIMARY KEY,
    tag_group_id INTEGER NOT NULL,
    acl_id INTEGER NOT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigner_id INTEGER DEFAULT NULL
)
ADD CONSTRAINT fk_tag_group_acl_tag_group_id FOREIGN KEY (tag_group_id) REFERENCES missionbase.tag_groups(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_tag_group_acl_acl_id FOREIGN KEY (acl_id) REFERENCES missionbase.acl_list(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_tag_group_acl_assigner_id FOREIGN KEY (assigner_id) REFERENCES missionbase.users(id) ON DELETE SET NULL;

CREATE TRIGGER delete_tag_group_acl_list_item AFTER DELETE ON missionbase.tag_group_acl FOR EACH ROW EXECUTE FUNCTION missionbase.delete_acl_list_item();

CREATE TABLE IF NOT EXISTS missionbase.tag_groupings (
    id SERIAL PRIMARY KEY,
    tag_group_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
ADD CONSTRAINT fk_tag_group_tags_tag_group_id FOREIGN KEY (tag_group_id) REFERENCES missionbase.tag_groups(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_tag_group_tags_tag_id FOREIGN KEY (tag_id) REFERENCES missionbase.tags(id) ON DELETE CASCADE;

CREATE TABLE IF NOT EXISTS missionbase.contact_taxonomy (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    expires TIMESTAMP GENERATED ALWAYS AS (
        CASE WHEN (SELECT ttl FROM missionbase.tags WHERE id = contact_taxonomy.tag_id) IS NOT NULL
        THEN updated_datetime + (SELECT ttl FROM missionbase.tags WHERE id = contact_taxonomy.tag_id)
        ELSE NULL
        END
    ) STORED,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION missionbase.delete_expired_taxonomy() RETURNS VOID AS $$
BEGIN
    DELETE FROM missionbase.contact_taxonomy WHERE expires < NOW();
END;
$$ LANGUAGE plpgsql;

--This may not work in all environments of postgres
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule('0 3 * * *', $$CALL missionbase.delete_exired_taxonomy()$$);

CREATE TABLE IF NOT EXISTS missionbase.recurrence_patterns (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT NULL,
    every_n_days INTEGER DEFAULT NULL COMMENT 'cannot be used with n weeks, months, or years',
    every_n_weeks INTEGER DEFAULT NULL COMMENT 'cannot be used with n days, months, or years',
    every_n_months INTEGER DEFAULT NULL COMMENT 'cannot be used with n days, weeks, or years'
    every_n_years INTEGER DEFAULT NULL COMMENT 'cannot be used with n days, weeks, or months',
    days_of_month INTEGER[] DEFAULT NULL,
    days_of_week INTEGER[] DEFAULT NULL,
    weeks_of_month INTEGER[] DEFAULT NULL,
    months_of_year INTEGER[] DEFAULT NULL,
    exclusion_dates TIMESTAMP[] DEFAULT NULL COMMENT 'if scheduled event falls on this date, the next unexcluded date will be used.',
    inclusion_dates TIMESTAMP[] DEFAULT NULL,
    week_start_day INTEGER DEFAULT 0,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS missionbase.events (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT NULL,
    start_time TIMESTAMP NOT NULL,
    duration INTERVAL DEFAULT NULL,
    location INTEGER DEFAULT NULL,
    host_contact INTEGER DEFAULT NULL,
    organizer_contact INTEGER DEFAULT NULL,
    all_day BOOLEAN DEFAULT FALSE,
    busy BOOLEAN DEFAULT TRUE,
    allow_registration BOOLEAN DEFAULT FALSE,
    rsvp_required BOOLEAN DEFAULT FALSE,
    parent_event INTEGER DEFAULT NULL,
    occurrences INTEGER[] DEFAULT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    public BOOLEAN DEFAULT FALSE
)
ADD CONSTRAINT fk_events_location FOREIGN KEY (location) REFERENCES missionbase.locations(id) ON DELETE RESTRICT,
ADD CONSTRAINT fk_events_host_contact FOREIGN KEY (host_contact) REFERENCES missionbase.contacts(id) ON DELETE RESTRICT,
ADD CONSTRAINT fk_events_parent_event FOREIGN KEY (parent_event) REFERENCES missionbase.events(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_events_organizer_contact FOREIGN KEY (organizer_contact) REFERENCES missionbase.contacts(id) ON DELETE RESTRICT;

CREATE TRIGGER events BEFORE
UPDATE ON missionbase.events FOR EACH ROW EXECUTE FUNCTION missionbase.update_updated_datetime();

CREATE TABLE IF NOT EXISTS missionbase.event_recurrence (
    id SERIAL PRIMARY KEY,
    event_id INTEGER NOT NULL,
    pattern_id INTEGER NOT NULL,
    start_date TIMESTAMP NOT NULL,
    calculated_to TIMESTAMP DEFAULT NULL,
    end_date TIMESTAMP DEFAULT NULL,
    after_n_occurrences INTEGER DEFAULT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
ADD CONSTRAINT fk_event_recurrence_event_id FOREIGN KEY (event_id) REFERENCES missionbase.events(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_event_recurrence_pattern_id FOREIGN KEY (pattern_id) REFERENCES missionbase.recurrence_patterns(id) ON DELETE RESTRICT;

CREATE OR REPLACE FUNCTION missionbase.generate_next_occurrence() RETURNS TRIGGER AS $$
-- DECLARE
--     pattern missionbase.recurrence_patterns%ROWTYPE;
--     event missionbase.events%ROWTYPE;
--     next_occurrence TIMESTAMP;
BEGIN
    -- SELECT INTO pattern FROM missionbase.recurrence_patterns WHERE id = NEW.pattern_id;
    -- SELECT INTO event FROM missionbase.events WHERE id = NEW.event_id;

    -- next_occurrence := event.start_time;

    -- IF pattern.every_n_years IS NOT NULL THEN
    --     next_occurrence := next_occurrence + (pattern.every_n_years * INTERVAL '1 year');
    -- END IF;

    -- IF pattern.every_n_months IS NOT NULL THEN
    --     next_occurrence := next_occurrence + (pattern.every_n_months * INTERVAL '1 month');
    -- END IF;

    -- IF pattern.every_n_weeks IS NOT NULL THEN
    --     next_occurrence := next_occurrence + (pattern.every_n_weeks * INTERVAL '1 week');
    -- END IF;

    -- IF pattern.every_n_days IS NOT NULL THEN
    --     next_occurrence := next_occurrence + (pattern.every_n_days * INTERVAL '1 day');
    -- END IF;

    -- FIXME: implement the rest of the logic here... (chatgpt and co-pilot had
    -- many suggestions, but none of them were correct or close enough to walk
    -- through correcting them)    

END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS missionbase.event_acl (
    id SERIAL PRIMARY KEY,
    event_id INTEGER NOT NULL,
    acl_id INTEGER NOT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigner_id INTEGER DEFAULT NULL
)
ADD CONSTRAINT fk_event_acl_event_id FOREIGN KEY (event_id) REFERENCES missionbase.events(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_event_acl_acl_id FOREIGN KEY (acl_id) REFERENCES missionbase.acl_list(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_event_acl_assigner_id FOREIGN KEY (assigner_id) REFERENCES missionbase.users(id) ON DELETE SET NULL;

CREATE TRIGGER delete_event_acl_list_item AFTER DELETE ON missionbase.event_acl FOR EACH ROW EXECUTE FUNCTION missionbase.delete_acl_list_item();

CREATE TABLE IF NOT EXISTS missionbase.event_attendees (
    id SERIAL PRIMARY KEY,
    event_id INTEGER NOT NULL,
    contact_id INTEGER NOT NULL,
    attending BOOLEAN DEFAULT FALSE,
    added_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    confirmed_datetime TIMESTAMP DEFAULT NULL,
    attended BOOLEAN DEFAULT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
ADD CONSTRAINT fk_event_attendees_event_id FOREIGN KEY (event_id) REFERENCES missionbase.events(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_event_attendees_contact_id FOREIGN KEY (contact_id) REFERENCES missionbase.contacts(id) ON DELETE CASCADE,
ADD CONSTRAINT uq_event_attendees UNIQUE (event_id, contact_id);

CREATE TABLE IF NOT EXISTS missionbase.event_meta (
    id SERIAL PRIMARY KEY,
    event_id INTEGER NOT NULL,
    meta_type INTEGER NOT NULL,
    meta_key VARCHAR(255) NOT NULL,
    meta_value TEXT DEFAULT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
ADD CONSTRAINT fk_event_meta_event_id FOREIGN KEY (event_id) REFERENCES missionbase.events(id) ON DELETE CASCADE
ADD CONSTRAINT fk_event_meta_meta_type FOREIGN KEY (meta_type) REFERENCES missionbase.meta_types(id) ON DELETE RESTRICT;

CREATE TABLE IF NOT EXISTS missionbase.event_meta_acl (
    id SERIAL PRIMARY KEY,
    event_meta_id INTEGER NOT NULL,
    acl_id INTEGER NOT NULL,
    created_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigner_id INTEGER DEFAULT NULL
)
ADD CONSTRAINT fk_event_meta_acl_event_meta_id FOREIGN KEY (event_meta_id) REFERENCES missionbase.event_meta(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_event_meta_acl_acl_id FOREIGN KEY (acl_id) REFERENCES missionbase.acl_list(id) ON DELETE CASCADE,
ADD CONSTRAINT fk_event_meta_acl_assigner_id FOREIGN KEY (assigner_id) REFERENCES missionbase.users(id) ON DELETE SET NULL;

CREATE TRIGGER delete_event_meta_acl_list_item AFTER DELETE ON missionbase.event_meta_acl FOR EACH ROW EXECUTE FUNCTION missionbase.delete_acl_list_item();
