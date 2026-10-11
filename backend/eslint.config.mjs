import tsParser from '@typescript-eslint/parser';
import tsPlugin from '@typescript-eslint/eslint-plugin';

export default [
  {
    ignores: ['dist/**', 'node_modules/**'],
  },
  {
    files: ['src/**/*.ts'],
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
      },
    },
    plugins: {
      '@typescript-eslint': tsPlugin,
    },
    rules: {
      // Un @Body() typé Record, objet inline, any ou unknown échappe à la
      // ValidationPipe globale (whitelist / forbidNonWhitelisted ne voient
      // qu'une classe DTO). C'est la cause commune du crash du coach, des
      // quotas IA sans borne et des achats non vérifiés corrigés par l'audit.
      // Les usages hérités portent une exception explicite, à migrer.
      'no-restricted-syntax': [
        'error',
        ...[
          'TSTypeReference[typeName.name="Record"]',
          'TSTypeLiteral',
          'TSAnyKeyword',
          'TSUnknownKeyword',
        ].map((type) => ({
          selector: `Identifier:has(Decorator CallExpression[callee.name="Body"]) > TSTypeAnnotation > ${type}`,
          message:
            '@Body() doit être une classe DTO validée par class-validator (pas Record, objet inline, any ni unknown).',
        })),
      ],
    },
  },
];
