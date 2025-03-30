const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");

const snsClient = new SNSClient();

exports.handler = async (event) => {
    console.log('Received event:', JSON.stringify(event, null, 2));

    const snsTopicArn = process.env.SNS_TOPIC_ARN; // 환경 변수로 SNS 토픽 ARN 설정

    const message = {
        subject: 'AWS Config Rule Violation Detected',
        message: `A non-compliant resource has been detected:
        Rule: ${event.detail.configRuleName}
        Resource: ${event.detail.resourceId}
        Resource Type: ${event.detail.resourceType}
        Compliance Status: ${event.detail.newEvaluationResult.complianceType}
        Time: ${event.detail.notificationCreationTime}`
    };

    const params = {
        Message: JSON.stringify(message),
        TopicArn: snsTopicArn
    };

    try {
        const command = new PublishCommand(params);
        await snsClient.send(command);
        console.log('Message published to SNS');
        return { statusCode: 200, body: 'Notification sent successfully' };
    } catch (error) {
        console.error('Error publishing to SNS', error);
        return { statusCode: 500, body: 'Failed to send notification' };
    }
};
