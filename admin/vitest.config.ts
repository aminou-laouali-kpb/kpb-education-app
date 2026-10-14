import { defineConfig } from 'vitest/config';

// Next compile le JSX lui-même (`"jsx": "preserve"` dans tsconfig) ; vitest
// doit le transformer pour rendre les composants `.tsx` côté serveur
// (`react-dom/server`) dans les tests. Environnement node, comme avant.
export default defineConfig({
  oxc: { jsx: { runtime: 'automatic', importSource: 'react' } },
  test: { environment: 'node' },
});
