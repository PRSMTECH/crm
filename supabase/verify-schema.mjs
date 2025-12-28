import pg from 'pg';

const { Client } = pg;

const connectionString = 'postgres://postgres.qewgfglkxmngvxezbern:%23prsmtechsql00@aws-1-us-west-1.pooler.supabase.com:5432/postgres';

async function verifySchema() {
  const client = new Client({ connectionString });

  try {
    await client.connect();
    console.log('=== PRSM-Frappuccino Schema Verification ===\n');

    // Check RLS enabled
    const rlsResult = await client.query(`
      SELECT tablename, rowsecurity
      FROM pg_tables
      WHERE schemaname = 'prsm_frappuccino';
    `);
    console.log('RLS Status:');
    rlsResult.rows.forEach(row => {
      const status = row.rowsecurity ? '✅' : '❌';
      console.log(`  ${status} ${row.tablename}`);
    });

    // Check policies
    const policiesResult = await client.query(`
      SELECT schemaname, tablename, policyname
      FROM pg_policies
      WHERE schemaname = 'prsm_frappuccino'
      ORDER BY tablename;
    `);
    console.log(`\nRLS Policies: ${policiesResult.rows.length} policies created`);

    // Check seed data
    const leadSourcesResult = await client.query(`
      SELECT name FROM prsm_frappuccino.lead_sources ORDER BY name;
    `);
    console.log(`\nLead Sources (${leadSourcesResult.rows.length}):`);
    leadSourcesResult.rows.forEach(row => console.log(`  - ${row.name}`));

    const pipelineResult = await client.query(`
      SELECT pipeline_type, name, probability, color
      FROM prsm_frappuccino.pipeline_stages
      ORDER BY pipeline_type, position;
    `);
    console.log(`\nPipeline Stages (${pipelineResult.rows.length}):`);
    let currentType = '';
    pipelineResult.rows.forEach(row => {
      if (row.pipeline_type !== currentType) {
        currentType = row.pipeline_type;
        console.log(`  ${currentType.toUpperCase()}:`);
      }
      console.log(`    - ${row.name} (${(row.probability * 100).toFixed(0)}%)`);
    });

    const activityTypesResult = await client.query(`
      SELECT name, icon FROM prsm_frappuccino.activity_types ORDER BY name;
    `);
    console.log(`\nActivity Types (${activityTypesResult.rows.length}):`);
    activityTypesResult.rows.forEach(row => console.log(`  - ${row.name} (${row.icon})`));

    console.log('\n=== Verification Complete ===');

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await client.end();
  }
}

verifySchema();
