// Copyright (c) Wiadvance Corporation. All rights reserved.

// index.js is used to setup and configure your bot

// Import required packages
const path = require('path')
const fs   = require('fs')

//Local env variable
const ENV_FILE = path.join(__dirname, '.env')
if(fs.existsSync(ENV_FILE)) {
    require('dotenv').config({ path: ENV_FILE })
}

const restify = require('restify')

// Mysql
const mysqlUtil = require('./util/mysql')
mysqlUtil.init()

// Import required bot services.
// See https://aka.ms/bot-services to learn more about the different parts of a bot.
const {
    ActivityTypes,
    CloudAdapter,
    ConfigurationServiceClientCredentialFactory,
    createBotFrameworkAuthenticationFromConfiguration
} = require('botbuilder')

// The bot.
const { Wiabot } = require('./bots/wiabot');

const credentialsFactory = new ConfigurationServiceClientCredentialFactory({
    MicrosoftAppId: process.env.MicrosoftAppId,
    MicrosoftAppPassword: process.env.MicrosoftAppPassword,
    MicrosoftAppTenantId: process.env.MicrosoftAppTenantId
});

const botFrameworkAuthentication = createBotFrameworkAuthenticationFromConfiguration(null, credentialsFactory)

// Create adapter.
// See https://aka.ms/about-bot-adapter to learn more about adapters.
const adapter = new CloudAdapter(botFrameworkAuthentication)

// Catch-all for errors.
adapter.onTurnError = async (context, error) => { 
    // Create a trace activity that contains the error object
    const traceActivity = {
        type: ActivityTypes.Trace,
        timestamp: new Date(),
        name: 'onTurnError Trace',
        label: 'TurnError',
        value: `${ error }`,
        valueType: 'https://www.botframework.com/schemas/error'
    };
    // This check writes out errors to console log .vs. app insights.
    // NOTE: In production environment, you should consider logging this to Azure
    //       application insights. See https://aka.ms/bottelemetry for telemetry
    //       configuration instructions.
    console.error(`\n [onTurnError] unhandled error: ${ error }`)
};

const bot = new Wiabot()

// Create HTTP server
const server = restify.createServer()
server.use(restify.plugins.bodyParser())

server.listen(process.env.port || process.env.PORT || 3978, async function() {
    //console.log(`Listening to ${ server.url }`)
});

// Listen for incoming activities and route them to your bot main dialog.
server.post('/api/messages', async (req, res) => {
    // Route received a request to adapter for processing
    await adapter.process(req, res, (context) => bot.run(context))
});

server.post('/api/notify', async (req, res) => {
    let message = req.body.message;
    let user = req.body.user;
    if(message == undefined || message == "" || user == undefined || user == "") {
        res.setHeader('Content-Type', 'application/json')
        res.writeHead(200)
        res.end(JSON.stringify({
            status: 0,
            error_msg: 'parameter error.'
        }))
        return
    }

    let resData = {
        status: 1,
        user_record_exist: 1 
    }
    try {
        let teamsMember = await mysqlUtil.getUserInfo(req.body.user);
        if(teamsMember.length > 0) {
            await sendMessage(teamsMember[0]["conversation_id"], message);
        } else {
            resData["user_record_exist"] = 0;
        }

        res.setHeader('Content-Type', 'application/json');
        res.writeHead(200);
        res.end(JSON.stringify(resData));
    } catch(e) {
        res.setHeader('Content-Type', 'application/json');
        res.writeHead(200);
        res.end(JSON.stringify({
            status: 0,
            error_msg: e.message
        })); 
    }
});

const sendMessage = async function (conversationId, msg) {
    let conversationReferences = {
        text: msg,
        textFormat: 'plain',
        type: 'message',
        channelId: 'msteams',
        serviceUrl: 'https://smba.trafficmanager.net/apac/',
        conversation: {
            conversationType: 'personal',
            tenantId: process.env.MicrosoftAppTenantId,
            id: conversationId
        },
        entities: [],
        channelData: { tenant: { id: process.env.MicrosoftAppTenantId } }
    }
    
    await adapter.continueConversationAsync(process.env.MicrosoftAppId, conversationReferences , async context => {
        await context.sendActivity(msg);       
    });
}