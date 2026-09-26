#!/usr/bin/env node
/**
 * Provider Configuration Script for OpenClaw
 * Automatically updates openclaw.json and creates secret files
 * 
 * Usage: node provider_config.js --provider <name> --base-url <url> --model <model> --api-key <key>
 * 
 * This script:
 * 1. Reads /root/.openclaw/openclaw.json
 * 2. Updates or creates provider configuration
 * 3. Creates/updates secret file for API key
 * 4. Updates secrets section in openclaw.json
 */

const fs = require('fs');
const path = require('path');

const OPENCLAW_CONFIG = '/root/.openclaw/openclaw.json';
const SECRETS_DIR = '/root/.openclaw/secrets';

function parseArgs() {
    const args = process.argv.slice(2);
    const config = {};
    
    for (let i = 0; i < args.length; i += 2) {
        const key = args[i].replace('--', '');
        const value = args[i + 1];
        config[key] = value;
    }
    
    return config;
}

function updateProviderConfig(provider, baseUrl, model, apiKey) {
    // Read current config
    let config;
    try {
        const configContent = fs.readFileSync(OPENCLAW_CONFIG, 'utf8');
        config = JSON.parse(configContent);
    } catch (e) {
        console.error('Error reading openclaw.json:', e.message);
        process.exit(1);
    }
    
    // Ensure models.providers exists
    if (!config.models) {
        config.models = { mode: 'merge', providers: {} };
    }
    if (typeof config.models === 'string') {
        config.models = { mode: 'merge', providers: {} };
    }
    if (!config.models.providers) {
        config.models.providers = {};
    }
    
    // Update provider configuration
    config.models.providers[provider] = {
        baseUrl: baseUrl,
        models: [{
            id: model,
            name: model,
            reasoning: false,
            input: ['text'],
            contextWindow: 100000,
            maxTokens: 32768
        }],
        timeoutSeconds: 300,
        maxTokens: 32768,
        apiKey: {
            source: 'file',
            provider: provider + '_key',
            id: 'value'
        }
    };
    
    // Create secret file if API key provided
    if (apiKey) {
        const secretPath = path.join(SECRETS_DIR, `${provider}.key`);
        try {
            fs.writeFileSync(secretPath, apiKey.trim() + '\n', { mode: 0o600 });
            console.log(`✓ Created secret file: ${secretPath}`);
        } catch (e) {
            console.error('Error creating secret file:', e.message);
        }
        
        // Add secret provider entry if not exists
        if (!config.secrets) {
            config.secrets = { providers: {} };
        }
        if (!config.secrets.providers) {
            config.secrets.providers = {};
        }
        
        config.secrets.providers[provider + '_key'] = {
            source: 'file',
            path: secretPath,
            mode: 'singleValue'
        };
    }
    
    // Write updated config
    try {
        fs.writeFileSync(OPENCLAW_CONFIG, JSON.stringify(config, null, 2) + '\n');
        console.log(`✓ Updated provider '${provider}' in openclaw.json`);
    } catch (e) {
        console.error('Error writing openclaw.json:', e.message);
        process.exit(1);
    }
    
    return true;
}

function main() {
    const config = parseArgs();
    
    if (!config.provider || !config['base-url'] || !config.model) {
        console.log(`
Usage: node provider_config.js --provider <name> --base-url <url> --model <model> [--api-key <key>]

Examples:
  # Add dashscope provider with API key
  node provider_config.js --provider dashscope \\
    --base-url "https://dashscope-intl.aliyuncs.com/compatible-mode/v1" \\
    --model "deepseek-v4-flash" \\
    --api-key "your-api-key-here"

  # Update existing provider
  node provider_config.js --provider vyce \\
    --base-url "https://vyceai.com/v1" \\
    --model "deepseek-v4-flash"

  # Update provider (API key from existing secret file)
  node provider_config.js --provider mymodel \\
    --base-url "https://api.example.com/v1" \\
    --model "gpt-4"
`);
        process.exit(1);
    }
    
    console.log(`
Configuring provider: ${config.provider}
  Base URL: ${config['base-url']}
  Model: ${config.model}
  API Key: ${config['api-key'] ? '✓ Set' : '✗ Not provided'}
`);
    
    updateProviderConfig(
        config.provider,
        config['base-url'],
        config.model,
        config['api-key']
    );
    
    console.log('\n✓ Provider configuration complete!');
    console.log('  - Configuration updated in openclaw.json');
    console.log('  - Secret file created if API key was provided');
    console.log('\nTo apply changes:');
    console.log('  openclaw reload   # Reload gateway');
    console.log('  openclaw models   # Verify provider');
}

main();