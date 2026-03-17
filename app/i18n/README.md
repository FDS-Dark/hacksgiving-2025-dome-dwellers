# Internationalization (i18n) Setup

This app uses automatic language detection and translation support for multiple languages.

## How It Works

The app automatically detects the device's language when it starts and displays all text in that language. If the device language isn't supported, it falls back to English.

## Supported Languages

- **English (en)** - Default
- **Spanish (es)** - Español
- **French (fr)** - Français
- **German (de)** - Deutsch

## File Structure

```
i18n/
├── index.ts              # Main i18n configuration
├── locales/
│   ├── en.ts            # English translations
│   ├── es.ts            # Spanish translations
│   ├── fr.ts            # French translations
│   └── de.ts            # German translations
└── README.md            # This file
```

## Usage in Components

### Basic Usage

```typescript
import { useTranslation } from '@/hooks/useTranslation';

function MyComponent() {
  const { t } = useTranslation();
  
  return (
    <Text>{t('tickets.title')}</Text>
  );
}
```

### With Interpolation

```typescript
import { useTranslation } from '@/hooks/useTranslation';

function MyComponent() {
  const { t } = useTranslation();
  const count = 5;
  
  return (
    <Text>{t('giftShop.cart', { count })}</Text>
  );
}
```

### Manually Change Language (Optional)

```typescript
import { useTranslation } from '@/hooks/useTranslation';

function LanguageSwitcher() {
  const { changeLanguage, locale } = useTranslation();
  
  return (
    <Button 
      title="Switch to Spanish" 
      onPress={() => changeLanguage('es')} 
    />
  );
}
```

## Adding a New Language

1. Create a new translation file in `i18n/locales/` (e.g., `zh.ts` for Chinese)
2. Copy the structure from `en.ts` and translate all strings
3. Import and add it to `i18n/index.ts`:

```typescript
import zh from './locales/zh';

const i18n = new I18n({
  en,
  es,
  fr,
  de,
  zh, // Add your new language here
});
```

4. Update the `getAvailableLanguages()` function in `i18n/index.ts`:

```typescript
export const getAvailableLanguages = () => {
  return [
    { code: 'en', name: 'English' },
    { code: 'es', name: 'Español' },
    { code: 'fr', name: 'Français' },
    { code: 'de', name: 'Deutsch' },
    { code: 'zh', name: '中文' }, // Add your language
  ];
};
```

## Translation Keys Structure

```typescript
{
  common: {
    // Common UI elements
    back: 'Back',
    menu: 'Menu',
    // ...
  },
  home: {
    // Home screen
  },
  tickets: {
    // Tickets screen
  },
  donation: {
    // Donation screen
  },
  giftShop: {
    // Gift shop screen
  },
  success: {
    // Success screen
  },
  cancel: {
    // Cancel screen
  },
}
```

## Testing Different Languages

### On iOS Simulator
1. Go to Settings → General → Language & Region
2. Add or change the preferred language
3. Restart the app

### On Android Emulator
1. Go to Settings → System → Languages & input → Languages
2. Add or change the language
3. Restart the app

### Programmatically (for testing)
```typescript
import { changeLanguage } from '@/i18n';

// In your component or test
changeLanguage('es'); // Switch to Spanish
```

## Best Practices

1. **Always use translation keys**: Never hardcode strings in components
2. **Keep keys descriptive**: Use clear, hierarchical keys (e.g., `tickets.error.checkoutFailed`)
3. **Test all languages**: Verify that text fits in UI elements across all languages
4. **Handle pluralization**: Use interpolation for dynamic content (e.g., item counts)
5. **Provide context**: Add comments in translation files for ambiguous strings

## Troubleshooting

### App not detecting device language
- Make sure `expo-localization` is installed
- Check that the language code matches exactly (e.g., `en`, not `en-US`)
- The app falls back to English if the language isn't supported

### Translations not updating
- Make sure you're using the `useTranslation` hook
- Check that the translation key exists in all language files
- Restart the development server after adding new translations

### Text overflowing in some languages
- Some languages (like German) use longer words
- Test your UI with all languages
- Use flexible layouts (avoid fixed widths)
- Consider using smaller font sizes for longer translations

## Dependencies

- `i18n-js`: Lightweight internationalization library
- `expo-localization`: Provides device locale information

