module.exports = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: 'src',
  testRegex: '.*\\.spec\\.ts$',
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  collectCoverageFrom: ['**/*.ts', '!**/node_modules/**', '!**/dist/**'],
  coverageDirectory: '../coverage',
  testEnvironment: 'node',
  // Specs Postgres : session SQL en UTC, comme en CI et en production.
  setupFiles: ['<rootDir>/../jest.postgres-utc.js'],
};
