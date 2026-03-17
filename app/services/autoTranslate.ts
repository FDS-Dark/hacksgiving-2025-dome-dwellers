/**
 * Auto-Translation Service
 * 
 * This service automatically translates dynamic content (like product descriptions)
 * without requiring manual translation files for every language.
 * 
 * Features:
 * - Multiple translation providers (Google, LibreTranslate, DeepL)
 * - Automatic caching to minimize API calls
 * - Falls back to English if translation fails
 * - Minimal cost for non-profits
 */

import AsyncStorage from '@react-native-async-storage/async-storage';

// Translation cache
const translationCache = new Map<string, string>();
const CACHE_KEY_PREFIX = '@translations_';

/**
 * Translation Provider Configuration
 */
type TranslationProvider = 'libretranslate' | 'google' | 'deepl' | 'mymemory';

interface TranslationConfig {
  provider: TranslationProvider;
  apiKey?: string; // Optional for free providers
  apiUrl?: string; // Custom API URL
}

// Configure your translation provider here
const config: TranslationConfig = {
  provider: 'libretranslate', // FREE and open-source!
  apiUrl: 'https://libretranslate.com/translate', // Free public instance
};

/**
 * Generate cache key
 */
const getCacheKey = (text: string, targetLang: string): string => {
  return `${CACHE_KEY_PREFIX}${targetLang}_${text.substring(0, 50)}`;
};

/**
 * Load translation from cache
 */
const loadFromCache = async (text: string, targetLang: string): Promise<string | null> => {
  const cacheKey = getCacheKey(text, targetLang);
  
  // Try memory cache first
  if (translationCache.has(cacheKey)) {
    return translationCache.get(cacheKey)!;
  }
  
  // Try persistent storage
  try {
    const cached = await AsyncStorage.getItem(cacheKey);
    if (cached) {
      translationCache.set(cacheKey, cached);
      return cached;
    }
  } catch (error) {
    console.warn('Cache read error:', error);
  }
  
  return null;
};

/**
 * Save translation to cache
 */
const saveToCache = async (text: string, targetLang: string, translation: string) => {
  const cacheKey = getCacheKey(text, targetLang);
  translationCache.set(cacheKey, translation);
  
  try {
    await AsyncStorage.setItem(cacheKey, translation);
  } catch (error) {
    console.warn('Cache write error:', error);
  }
};

/**
 * Translate using LibreTranslate (FREE!)
 */
const translateWithLibreTranslate = async (
  text: string,
  targetLang: string,
  apiUrl: string
): Promise<string> => {
  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      q: text,
      source: 'en',
      target: targetLang,
      format: 'text',
    }),
  });

  if (!response.ok) {
    throw new Error(`Translation failed: ${response.statusText}`);
  }

  const data = await response.json();
  return data.translatedText;
};

/**
 * Translate using MyMemory (FREE!)
 * No API key needed, 5000 chars/day limit
 */
const translateWithMyMemory = async (
  text: string,
  targetLang: string
): Promise<string> => {
  const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=en|${targetLang}`;
  
  const response = await fetch(url);
  const data = await response.json();
  
  if (data.responseStatus !== 200) {
    throw new Error('Translation failed');
  }
  
  return data.responseData.translatedText;
};

/**
 * Translate using Google Translate (PAID but cheap)
 * Requires API key from Google Cloud
 */
const translateWithGoogle = async (
  text: string,
  targetLang: string,
  apiKey: string
): Promise<string> => {
  const url = `https://translation.googleapis.com/language/translate/v2?key=${apiKey}`;
  
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      q: text,
      target: targetLang,
      source: 'en',
    }),
  });

  if (!response.ok) {
    throw new Error(`Translation failed: ${response.statusText}`);
  }

  const data = await response.json();
  return data.data.translations[0].translatedText;
};

/**
 * Translate using DeepL (PAID but high quality)
 * Requires API key from DeepL
 */
const translateWithDeepL = async (
  text: string,
  targetLang: string,
  apiKey: string
): Promise<string> => {
  const url = 'https://api-free.deepl.com/v2/translate';
  
  const formData = new URLSearchParams();
  formData.append('text', text);
  formData.append('target_lang', targetLang.toUpperCase());
  formData.append('source_lang', 'EN');
  formData.append('auth_key', apiKey);

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: formData,
  });

  if (!response.ok) {
    throw new Error(`Translation failed: ${response.statusText}`);
  }

  const data = await response.json();
  return data.translations[0].text;
};

/**
 * Main translation function
 * Automatically caches and handles errors
 */
export const autoTranslate = async (
  text: string,
  targetLang: string
): Promise<string> => {
  // If target is English, return as-is
  if (targetLang === 'en' || !targetLang) {
    return text;
  }

  // Check cache first
  const cached = await loadFromCache(text, targetLang);
  if (cached) {
    return cached;
  }

  // Attempt translation
  try {
    let translation: string;

    switch (config.provider) {
      case 'libretranslate':
        translation = await translateWithLibreTranslate(
          text,
          targetLang,
          config.apiUrl || 'https://libretranslate.com/translate'
        );
        break;

      case 'mymemory':
        translation = await translateWithMyMemory(text, targetLang);
        break;

      case 'google':
        if (!config.apiKey) {
          throw new Error('Google Translate requires an API key');
        }
        translation = await translateWithGoogle(text, targetLang, config.apiKey);
        break;

      case 'deepl':
        if (!config.apiKey) {
          throw new Error('DeepL requires an API key');
        }
        translation = await translateWithDeepL(text, targetLang, config.apiKey);
        break;

      default:
        throw new Error(`Unknown provider: ${config.provider}`);
    }

    // Cache the translation
    await saveToCache(text, targetLang, translation);
    return translation;

  } catch (error) {
    console.warn(`Translation failed for "${text}" to ${targetLang}:`, error);
    // Fallback to original text
    return text;
  }
};

/**
 * Batch translate multiple texts
 * More efficient for translating many items at once
 */
export const autoTranslateBatch = async (
  texts: string[],
  targetLang: string
): Promise<string[]> => {
  const promises = texts.map(text => autoTranslate(text, targetLang));
  return Promise.all(promises);
};

/**
 * Clear translation cache
 * Useful for testing or forcing fresh translations
 */
export const clearTranslationCache = async () => {
  translationCache.clear();
  
  try {
    const keys = await AsyncStorage.getAllKeys();
    const translationKeys = keys.filter(key => key.startsWith(CACHE_KEY_PREFIX));
    await AsyncStorage.multiRemove(translationKeys);
  } catch (error) {
    console.warn('Error clearing cache:', error);
  }
};

