// sudachi-ios FFI Library
// This provides a C-compatible interface to Sudachi for use in iOS apps

use std::ffi::{CStr, CString};
use std::fs::File;
use std::os::raw::c_char;
use std::path::PathBuf;
use std::ptr;
use std::sync::Arc;
use memmap2::Mmap;
use sudachi::analysis::stateless_tokenizer::StatelessTokenizer;
use sudachi::analysis::Tokenize;
use sudachi::config::Config;
use sudachi::dic::dictionary::JapaneseDictionary;
use sudachi::dic::storage::{Storage, SudachiDicData};
use sudachi::prelude::*;

// Opaque pointer types for safer FFI
pub struct SudachiTokenizer {
    dictionary: Arc<JapaneseDictionary>,
    tokenizer: StatelessTokenizer<Arc<JapaneseDictionary>>,
}

#[repr(C)]
pub struct SudachiToken {
    surface: *mut c_char,
    reading: *mut c_char,
    dictionary_form: *mut c_char,
    normalized_form: *mut c_char,
    pos: *mut c_char,  // JSON array string
    begin: i32,
    end: i32,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub enum SudachiTokenMode {
    A = 0,  // Short units
    B = 1,  // Medium units (default)
    C = 2,  // Long units
}

impl From<SudachiTokenMode> for Mode {
    fn from(mode: SudachiTokenMode) -> Self {
        match mode {
            SudachiTokenMode::A => Mode::A,
            SudachiTokenMode::B => Mode::B,
            SudachiTokenMode::C => Mode::C,
        }
    }
}

/// Initialize Sudachi tokenizer with dictionary path
/// Returns NULL on failure
#[no_mangle]
pub extern "C" fn sudachi_init(dict_path: *const c_char) -> *mut SudachiTokenizer {
    if dict_path.is_null() {
        return ptr::null_mut();
    }

    let path = unsafe {
        match CStr::from_ptr(dict_path).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        }
    };

    // Create dictionary from path
    // We only have the dictionary file, no config or char.def
    // So we need to load the dictionary directly without Config
    let dict_pathbuf = PathBuf::from(path);
    
    // Try to load dictionary directly from file
    let file = match File::open(&dict_pathbuf) {
        Ok(f) => f,
        Err(_) => {
            eprintln!("Failed to open dictionary file: {}", path);
            return ptr::null_mut();
        }
    };
    
    let mapping = match unsafe { Mmap::map(&file) } {
        Ok(m) => m,
        Err(_) => {
            eprintln!("Failed to memory map dictionary file");
            return ptr::null_mut();
        }
    };
    
    let storage = Storage::File(mapping);
    let dic_data = SudachiDicData::new(storage);
    
    // Create minimal config for plugins
    // Use embedded chardef method - doesn't need external char.def file
    let mut config = Config::default();
    
    // Add minimal OOV provider plugin (required by Sudachi)
    config.oov_provider_plugins = vec![serde_json::json!({
        "class": "com.worksap.nlp.sudachi.SimpleOovPlugin",
        "oovPOS": ["名詞", "普通名詞", "一般", "*", "*", "*"],
        "leftId": 0,
        "rightId": 0,
        "cost": 30000
    })];
    
    // Use the embedded chardef variant - doesn't require external char.def file
    let dictionary = match JapaneseDictionary::from_cfg_storage_with_embedded_chardef(&config, dic_data) {
        Ok(dict) => Arc::new(dict),
        Err(e) => {
            eprintln!("Failed to create dictionary: {:?}", e);
            return ptr::null_mut();
        }
    };

    let tokenizer = StatelessTokenizer::new(dictionary.clone());

    Box::into_raw(Box::new(SudachiTokenizer {
        dictionary,
        tokenizer,
    }))
}

/// Tokenize text using Sudachi
/// Returns array of tokens (caller must free with sudachi_free_tokens)
#[no_mangle]
pub extern "C" fn sudachi_tokenize(
    tokenizer: *mut SudachiTokenizer,
    text: *const c_char,
    mode: SudachiTokenMode,
    out_count: *mut usize,
) -> *mut *mut SudachiToken {
    if tokenizer.is_null() || text.is_null() || out_count.is_null() {
        return ptr::null_mut();
    }

    let tokenizer = unsafe { &*tokenizer };
    let text_str = unsafe {
        match CStr::from_ptr(text).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        }
    };

    let mode: Mode = mode.into();

    // Tokenize
    let morphemes = match tokenizer.tokenizer.tokenize(text_str, mode, false) {
        Ok(morphemes) => morphemes,
        Err(_) => return ptr::null_mut(),
    };

        // Convert to C-compatible tokens
        let tokens: Vec<*mut SudachiToken> = morphemes
            .iter()
            .filter_map(|morpheme| {
                let surface = match CString::new(&*morpheme.surface()) {
                    Ok(s) => s.into_raw(),
                    Err(_) => return None,
                };

                let reading = CString::new(&*morpheme.reading_form())
                    .ok()
                    .map(|s| s.into_raw())
                    .unwrap_or(ptr::null_mut());

                let dict_form = CString::new(&*morpheme.dictionary_form())
                    .ok()
                    .map(|s| s.into_raw())
                    .unwrap_or(ptr::null_mut());

                let normalized = CString::new(&*morpheme.normalized_form())
                    .ok()
                    .map(|s| s.into_raw())
                    .unwrap_or(ptr::null_mut());

                // Serialize POS tags as JSON array
                let pos_tags = morpheme.part_of_speech();
                let pos_json = serde_json::to_string(&pos_tags).ok()
                    .and_then(|json| CString::new(json).ok())
                    .map(|s| s.into_raw())
                    .unwrap_or(ptr::null_mut());

                let begin = morpheme.begin() as i32;
                let end = morpheme.end() as i32;

                Some(Box::into_raw(Box::new(SudachiToken {
                    surface,
                    reading,
                    dictionary_form: dict_form,
                    normalized_form: normalized,
                    pos: pos_json,
                    begin,
                    end,
                })))
            })
            .collect();

    unsafe {
        *out_count = tokens.len();
    }

    // Convert Vec to C array
    let mut result_array = tokens.into_boxed_slice();
    let ptr = result_array.as_mut_ptr();
    Box::leak(result_array);
    ptr
}

/// Free a token
#[no_mangle]
pub extern "C" fn sudachi_free_token(token: *mut SudachiToken) {
    if token.is_null() {
        return;
    }

    unsafe {
        let token = Box::from_raw(token);
        
        if !token.surface.is_null() {
            let _ = CString::from_raw(token.surface);
        }
        if !token.reading.is_null() {
            let _ = CString::from_raw(token.reading);
        }
        if !token.dictionary_form.is_null() {
            let _ = CString::from_raw(token.dictionary_form);
        }
        if !token.normalized_form.is_null() {
            let _ = CString::from_raw(token.normalized_form);
        }
        if !token.pos.is_null() {
            let _ = CString::from_raw(token.pos);
        }
    }
}

/// Free array of tokens
#[no_mangle]
pub extern "C" fn sudachi_free_tokens(tokens: *mut *mut SudachiToken, count: usize) {
    if tokens.is_null() {
        return;
    }

    unsafe {
        let tokens_slice = std::slice::from_raw_parts_mut(tokens, count);
        for token_ptr in tokens_slice.iter() {
            if !token_ptr.is_null() {
                sudachi_free_token(*token_ptr);
            }
        }
        let _ = Box::from_raw(std::slice::from_raw_parts_mut(tokens, count));
    }
}

/// Free tokenizer
#[no_mangle]
pub extern "C" fn sudachi_free_tokenizer(tokenizer: *mut SudachiTokenizer) {
    if !tokenizer.is_null() {
        unsafe {
            let _ = Box::from_raw(tokenizer);
        }
    }
}

/// Get version string
#[no_mangle]
pub extern "C" fn sudachi_version() -> *const c_char {
    static VERSION: &str = concat!(env!("CARGO_PKG_VERSION"), "\0");
    VERSION.as_ptr() as *const c_char
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_ffi() {
        // This would need a valid dictionary path to run
        // Just ensure it compiles
    }
}