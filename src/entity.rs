// System User Structures

use chrono::NaiveDateTime;
use serde::{Deserialize, Serialize};

#[derive(Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum UserRole {
    User,
    Administrator,
    Canceled,
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct User {
    id: i32,                                       // smallint(5) unsigned
    uid: Option<String>,                           // varchar(25) NULL
    contact_uid: Option<String>,                   // varchar(25) NULL
    contact: Option<Contact>,                      // JOIN
    username: String,                              // varchar(40)
    user_pass: String,                             // varchar(255)
    api_salt: Option<String>,                      // varchar(255) NULL
    email: String,                                 // varchar(255)
    time_zone: String,                             // varchar(40)
    user_role: UserRole,                           // enum('user', 'administrator', 'canceled')
    created_datetime: NaiveDateTime,               // datetime
    updated_datetime: NaiveDateTime,               // datetime
    meta: Option<Vec<UserMeta>>,                   // JOIN
    groups: Option<Vec<GroupUser>>,                // JOIN
    login_history: Option<Vec<LoginHistory>>,      // JOIN
    created_churches: Option<Vec<Church>>,         // JOIN
    assigned_contacts: Option<Vec<ChurchContact>>, // JOIN
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UserMetaKey {
    Board,
    Field,
    FirstName,
    #[serde(rename = "fruuxCalEndpoint")]
    FruuxCalEndpoint,
    #[serde(rename = "fruuxContactsEndpoint")]
    FruuxContactsEndpoint,
    #[serde(rename = "fruuxPass")]
    FruuxPass,
    #[serde(rename = "fruuxRemindersEndpoint")]
    FruuxRemindersEndpoint,
    #[serde(rename = "fruuxUser")]
    FruuxUser,
    GoalDate,
    Homepage,
    #[serde(rename = "ifToAirtable")]
    IfToAirtable,
    #[serde(rename = "ifToFruux")]
    IfToFruux,
    LastName,
    SecurityAnswer,
    SecurityQuestion,
    SendingChurch,
    StartDate,
    StartSupportLevel,
    SupportLevel,
    Phone,
    Website,
    #[serde(rename = "airtableAPIKey")]
    AirtableApiKey,
    #[serde(rename = "airtableBASEkey")]
    AirtableBaseKey,
    #[serde(rename = "airtableCALENDARtable")]
    AirtableCalendarTable,
    #[serde(rename = "airtableCHURCHtable")]
    AirtableChurchTable,
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct UserMeta {
    id: i32,               // int(11)
    user_id: i32,          // smallint(5) unsigned
    user: User,            // JOIN
    meta_key: UserMetaKey, // varchar(255)
    meta_value: String,    // longtext
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct GroupUser {
    id: i32,              // int(11)
    group_id: i32,        // int(11)
    group: Option<Group>, // JOIN
    user_id: i32,         // smallint(5) unsigned
    user: Option<User>,   // JOIN
    access_level: i16,    // tinyint(4)
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct LoginHistory {
    id: i32,                  // int(10) unsigned
    user_id: i32,             // smallint(5) unsigned
    user: Option<User>,       // JOIN
    last_seen: NaiveDateTime, // datetime
    #[serde(rename = "HTTP_USER_AGENT")]
    http_user_agent: Option<String>, // varchar(300) NULL
    #[serde(rename = "REMOTE_ADDR")]
    remote_addr: Option<String>, // varchar(45) NULL
    #[serde(rename = "REQUEST_URI")]
    request_uri: Option<String>, // varchar(80000) NULL
    jwtid: Option<String>,    // varchar(32) NULL
}

// Public Structures

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct Church {
    id: i32,                                            // int(10) unsigned
    uid: Option<String>,                                // varchar(25) NULL
    guid: String,                                       // varchar(36)
    name: String,                                       // varchar(255)
    lat: Option<f64>,                                   // decimal(10,8)
    lon: Option<f64>,                                   // decimal(11,8)
    address: Option<String>,                            // varchar(255) NULL
    city: Option<String>,                               // varchar(255) NULL
    state: Option<String>,                              // varchar(255) NULL
    country: Option<String>,                            // varchar(255) NULL
    post_code: Option<String>,                          // varchar(10) NULL
    pastor_id: Option<i32>,                             // int(10) unsigned NULL
    pastor: Option<Contact>,                            // JOIN
    time_zone: Option<String>,                          // varchar(40) NULL
    creator_id: Option<i32>,                            // smallint(5) unsigned NULL
    creator: Option<User>,                              // JOIN
    created_datetime: NaiveDateTime,                    // datetime
    updated_datetime: NaiveDateTime,                    // datetime
    latlon: Option<String>,                             // varchar(40) NULL
    kjv_id: Option<i32>,                                // int(10) unsigned NULL
    contacts: Option<Vec<ChurchContact>>,               // JOIN
    group_taxonomies: Option<Vec<ChurchGroupTaxonomy>>, // JOIN
    meta: Option<Vec<ChurchMeta>>,                      // JOIN
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct ChurchContact {
    id: i32,                                 // int(10) unsigned
    church_id: i32,                          // int(10) unsigned
    church: Option<Church>,                  // JOIN
    contact_id: i32,                         // int(10) unsigned
    contact: Option<Contact>,                // JOIN
    position: String,                        // varchar(255)
    assigner_id: Option<i32>,                // smallint(5) unsigned NULL
    assigner: Option<User>,                  // JOIN
    changed_datetime: Option<NaiveDateTime>, // datetime NULL
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct ChurchGroupTaxonomy {
    id: i32,                            // int(10) unsigned
    church_id: i32,                     // int(10) unsigned
    church: Option<Church>,             // JOIN
    tag_id: i32,                        // int(10) unsigned
    tag: Option<GroupTag>,              // JOIN
    expire_date: Option<NaiveDateTime>, // datetime NULL
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct ChurchMeta {
    id: i32,                         // int(10) unsigned
    church_id: i32,                  // int(10) unsigned
    church: Option<Church>,          // JOIN
    meta_key: String,                // varchar(255)
    meta_value: String,              // longtext
    updated_datetime: NaiveDateTime, // datetime
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct ChurchTag {}

pub struct ChurchTagGrouping {}

pub struct ChurchTagGroup {}

pub struct ChurchTaxonomy {}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct Contact {
    pastors: Option<Vec<Church>>, // JOIN
}

pub struct ContactMeta {}

pub struct Event {}

pub struct EventAttendee {}

pub struct EventMeta {}

pub struct Flag {}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct Group {}

pub struct GroupId {}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct GroupTag {}

pub struct News {}

pub struct Note {}

pub struct NoteMeta {}

pub struct Point {}

pub struct SuggestedConfirms {}

pub struct SuggestedEdits {}

pub struct ZipRef {}

// Private User Structures

pub struct Activity {}

pub struct Calendar {}

pub struct CalendarEvent {}

// pub struct ChurchContact {}

pub struct ChurchMetaPrivate {}

pub struct ChurchStatus {}

pub struct Commitment {}

// pub struct Contact {}

// pub struct ContactMeta {}

pub struct ContactMetaPrivate {}

pub struct ContactStatus {}

// pub struct Event {}

// pub struct EventMeta {}

pub struct Income {}

// pub struct Note {}

// pub struct NoteMeta {}

pub struct PrivateChurchTaxonomy {}

pub struct Settings {}

pub struct Status {}

pub struct Task {}
