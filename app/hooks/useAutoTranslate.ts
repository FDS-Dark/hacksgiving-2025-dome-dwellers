/**
 * useAutoTranslate Hook
 * 
 * Makes it easy to automatically translate dynamic content
 * Perfect for: product names, descriptions, dynamic text
 * 
 * Usage:
 * const { t, autoT } = useAutoTranslate();
 * 
 * t('common.back')  // Uses manual translation files
 * autoT('New product name')  // Auto-translates on the fly
 */

import { useState, useEffect } from 'react';
import { useTranslation } from './useTranslation';
import { autoTranslate } from '@/services/autoTranslate';

export const useAutoTranslate = () => {
  const { t, locale, changeLanguage } = useTranslation();
  const [translationCache, setTranslationCache] = useState<Map<string, string>>(new Map());

  /**
   * Auto-translate text
   * Caches results for performance
   */
  const autoT = (text: string): string => {
    if (!text) return '';
    
    // Return English as-is
    if (locale === 'en') {
      return text;
    }

    // Check cache
    const cacheKey = `${locale}_${text}`;
    if (translationCache.has(cacheKey)) {
      return translationCache.get(cacheKey)!;
    }

    // Return original while translating in background
    // (Translation will update on next render)
    return text;
  };

  /**
   * Translate text and update cache
   */
  const translateAndCache = async (text: string) => {
    if (!text || locale === 'en') return;

    const cacheKey = `${locale}_${text}`;
    if (translationCache.has(cacheKey)) return;

    try {
      const translated = await autoTranslate(text, locale);
      setTranslationCache(prev => new Map(prev).set(cacheKey, translated));
    } catch (error) {
      console.warn('Auto-translation failed:', error);
    }
  };

  /**
   * Prefetch translations for an array of texts
   * Call this when you know what text you'll need
   */
  const prefetch = async (texts: string[]) => {
    if (locale === 'en') return;

    const promises = texts.map(text => translateAndCache(text));
    await Promise.all(promises);
  };

  return {
    t, // Manual translations (from files)
    autoT, // Auto-translate function
    translateAndCache, // Manually trigger translation
    prefetch, // Prefetch multiple translations
    locale,
    changeLanguage,
  };
};

/**
 * Hook specifically for translating an array of items
 * Perfect for product lists, menus, etc.
 */
export const useTranslatedItems = <T extends { name: string; description?: string }>(
  items: T[]
): T[] => {
  const { locale } = useTranslation();
  const [translatedItems, setTranslatedItems] = useState<T[]>(items);

  useEffect(() => {
    if (locale === 'en') {
      setTranslatedItems(items);
      return;
    }

    const translateItems = async () => {
      const translated = await Promise.all(
        items.map(async (item) => {
          const translatedName = await autoTranslate(item.name, locale);
          const translatedDescription = item.description
            ? await autoTranslate(item.description, locale)
            : undefined;

          return {
            ...item,
            name: translatedName,
            description: translatedDescription,
          };
        })
      );

      setTranslatedItems(translated);
    };

    translateItems();
  }, [items, locale]);

  return translatedItems;
};

