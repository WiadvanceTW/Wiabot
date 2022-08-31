// Copyright (c) Wiadvance Corporation. All rights reserved.
// Licensed under the MIT License.

const { ActivityHandler, TurnContext, TeamsInfo } = require('botbuilder')
const mysqlUtil = require('../util/mysql')

class Wiabot extends ActivityHandler {
    constructor() {
        super()

        // If a new user is added to the conversation, send them a greeting message
        this.onMembersAdded(async (context, next) => {
            let funcName = ''
            let membersAdded = context.activity.membersAdded;
            for (let cnt = 0; cnt < membersAdded.length; cnt++) {
                if (membersAdded[cnt].id !== context.activity.recipient.id && membersAdded[cnt].aadObjectId) {
                    try {
                        funcName = '[MYSQL] getTeamsMemberInfo';
                        let memberInfo = await mysqlUtil.getTeamsMemberInfo(membersAdded[cnt].id)
                        if(memberInfo.length == 0) {
                            funcName = '[TEAMS] getMember';
                            let member = await TeamsInfo.getMember(context, membersAdded[cnt].id)              
                            funcName = '[BOT] createConversationAsync'
                            await context.adapter.createConversationAsync(
                                process.env.MicrosoftAppId,
                                context.activity.channelId,
                                context.activity.serviceUrl,
                                null, { 
                                    tenantId: context.activity.channelData.tenant.id, 
                                    members: [membersAdded[cnt]] 
                                }, async (context) => {
                                    try {
                                        funcName = '[BOT] getConversationReference'
                                        let ref = TurnContext.getConversationReference(context.activity)
                                        funcName = '[MYSQL] createTeamsMemberInfo'
                                        let data = {
                                            name: member["name"], 
                                            member_id: member["id"],
                                            conversation_id: ref.conversation.id,
                                            email: member["email"]
                                        }
                                        await mysqlUtil.createTeamsMemberInfo(data)
                                    } catch(e) { 
                                        await mysqlUtil.addLog({
                                            level: 'ERROR',
                                            data: JSON.stringify(membersAdded[cnt]),
                                            error_message: e.message,
                                            func_name: funcName
                                        }) 
                                    }
                                }
                            )
                        }
                    } catch(e) {
                        await mysqlUtil.addLog({
                            level: 'ERROR',
                            data: JSON.stringify(membersAdded[cnt]),
                            error_message: e.message,
                            func_name: funcName
                        }) 
                    }
                }
            }

            // By calling next() you ensure that the next BotHandler is run.
            await next();
        }); 

        // When a user sends a message, perform a call to the QnA Maker service to retrieve matching Question and Answer pairs.
        this.onMessage(async (context, next) => {
            //Not do any things.
            await next()
        })
        
    }
}

module.exports.Wiabot = Wiabot