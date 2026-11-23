//! Android NDK JNI C-ABI Exports (`l4ne_core::jni_android`).
//!
//! Allows the Android Kotlin client (`com.l4ne.training.core.L4NECoreNative`)
//! to call `l4ne-core` directly via `System.loadLibrary("l4ne_core")` without external codegen.

use crate::db::L4neDatabase;
use crate::ffi::{execute_command_json_str, FfiEnvelope};
use crate::models::CoreError;
use serde_json::{json, Value};
use std::ffi::{c_void, CStr, CString};
use std::os::raw::c_char;

/// Minimal raw JNI Env function table for `GetStringUTFChars`, `ReleaseStringUTFChars`, and `NewStringUTF`
/// so `l4ne-core` compiles on every host target without requiring an external `jni` crate dependency.
#[repr(C)]
pub struct JNIEnvVTable {
    _reserved0: [*const c_void; 167],
    pub new_string_utf: unsafe extern "C" fn(*mut JNIEnv, *const c_char) -> *mut c_void,
    _reserved1: *const c_void,
    pub get_string_utf_chars:
        unsafe extern "C" fn(*mut JNIEnv, *mut c_void, *mut u8) -> *const c_char,
    pub release_string_utf_chars:
        unsafe extern "C" fn(*mut JNIEnv, *mut c_void, *const c_char),
}

pub type JNIEnv = *const JNIEnvVTable;

unsafe fn jstring_to_rust(env: *mut JNIEnv, jstr: *mut c_void) -> Option<String> {
    if env.is_null() || jstr.is_null() {
        return None;
    }
    let vtable = &*(*env);
    let mut is_copy: u8 = 0;
    let utf_ptr = (vtable.get_string_utf_chars)(env, jstr, &mut is_copy);
    if utf_ptr.is_null() {
        return None;
    }
    let rust_str = CStr::from_ptr(utf_ptr).to_string_lossy().into_owned();
    (vtable.release_string_utf_chars)(env, jstr, utf_ptr);
    Some(rust_str)
}

unsafe fn rust_to_jstring(env: *mut JNIEnv, s: String) -> *mut c_void {
    if env.is_null() {
        return std::ptr::null_mut();
    }
    let vtable = &*(*env);
    let cstr = CString::new(s)
        .unwrap_or_else(|_| CString::new(r#"{"ok":false,"error":"NUL byte"}"#).unwrap());
    (vtable.new_string_utf)(env, cstr.as_ptr())
}

/// JNI export: `com.l4ne.training.core.L4NECoreNative.initDatabaseJson(dbPath: String, seedDemo: Boolean): String`
#[no_mangle]
pub unsafe extern "C" fn Java_com_l4ne_training_core_L4NECoreNative_initDatabaseJson(
    env: *mut JNIEnv,
    _class: *mut c_void,
    j_db_path: *mut c_void,
    j_seed_demo: u8,
) -> *mut c_void {
    let Some(path_str) = jstring_to_rust(env, j_db_path) else {
        return rust_to_jstring(env, FfiEnvelope::failure("Invalid JNI dbPath string"));
    };
    let seed_demo = j_seed_demo != 0;
    let res = (|| -> Result<Value, CoreError> {
        let mut db = L4neDatabase::open(&path_str)?;
        let seeded = if seed_demo {
            db.seed_demo_data_if_empty()?
        } else {
            false
        };
        let templates = db.list_templates()?;
        Ok(json!({
            "seeded": seeded,
            "templates_count": templates.len(),
            "engine_version": "1.2.0"
        }))
    })();

    let json_out = match res {
        Ok(v) => FfiEnvelope::success(v),
        Err(e) => FfiEnvelope::failure(e.to_string()),
    };
    rust_to_jstring(env, json_out)
}

/// JNI export: `com.l4ne.training.core.L4NECoreNative.executeJson(dbPath: String, requestJson: String): String`
#[no_mangle]
pub unsafe extern "C" fn Java_com_l4ne_training_core_L4NECoreNative_executeJson(
    env: *mut JNIEnv,
    _class: *mut c_void,
    j_db_path: *mut c_void,
    j_request_json: *mut c_void,
) -> *mut c_void {
    let (Some(path_str), Some(req_str)) = (
        jstring_to_rust(env, j_db_path),
        jstring_to_rust(env, j_request_json),
    ) else {
        return rust_to_jstring(
            env,
            FfiEnvelope::failure("Invalid JNI dbPath or requestJson"),
        );
    };
    let response = execute_command_json_str(&path_str, &req_str);
    rust_to_jstring(env, response)
}
