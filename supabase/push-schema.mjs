import { readFileSync } from 'fs';
import pg from 'pg';

const { Client } = pg;

const connectionString = 'postgres://postgres.qewgfglkxmngvxezbern:%23prsmtechsql00@aws-1-us-west-1.pooler.supabase.com:5432/postgres';

async function pushSchema() {
  const client = new Client({ connectionString });

  try {
    console.log('Connecting to Supabase...');
    await client.connect();
    console.log('Connected!');

    // Read the schema file
    const schema = readFileSync('./prsm_frappuccino_schema.sql', 'utf8');

    console.log('Executing schema...');
    await client.query(schema);
    console.log('Schema deployed successfully!');

    // Verify tables
    const result = await client.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'prsm_frappuccino'
      ORDER BY table_name;
    `);

    console.log('\nCreated tables:');
    result.rows.forEach(row => console.log(`  - ${row.table_name}`));
    console.log(`\nTotal: ${result.rows.length} tables`);

  } catch (error) {
    console.error('Error:', error.message);
    throw error;
  } finally {
    await client.end();
  }
}

pushSchema();
