// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UserMailbox, UserMailboxInterface, Message} from "./UserMailbox.sol";

/**
 * @title Mailbox
 * @dev A contract for intermediate message exchange between parties.
 */
contract Mailbox {
    /// account who deployed the contract
    address private immutable owner;

    /// @dev Per user Mailbox holding all messages sent by different senders
    mapping (address => UserMailbox) mailboxes;

    /// @dev Max number of messages allowed for a single Mailbox (sender,recipient)
    uint256 constant public MAX_MESSAGES_PER_MAILBOX = 10;
    
    /// @notice Emitted when mailbox message count changes, new message arrival or message marked as read
    /// @param sender The address of the message sender
    /// @param recipient The address of the message recipient
    /// @param messagesCount Total number of messages in the Mailbox for (sender,recipient)
    /// @param timestamp Time when operation occurred
    event MailboxUpdated(address indexed sender, address indexed recipient, uint messagesCount, uint256 timestamp);

    /// @notice Raised on attempt to write a message when Mailbox is full
    error MailboxIsFull();

    /// @notice Raised on attempt to read a message when no unread messages left
    error MailboxIsEmpty();

    /// @notice Raised on failure to find the requested message
    error MessageNotFound();

    using UserMailboxInterface for UserMailbox;

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Writes a message to a dedicated Mailbox for (sender,recipient)
     * @param message The message to write
     * @param recipient Message recipient address
     */
    function writeMessage(bytes calldata message, address recipient) external {
        UserMailbox storage mailbox = mailboxes[recipient];
        uint256 msgCount = mailbox.countMessagesFrom(msg.sender);
        if (msgCount == MAX_MESSAGES_PER_MAILBOX) revert MailboxIsFull();

        Message memory _msg = Message({
            sender: msg.sender,
            data: message,
            sentAt: block.timestamp
        });
        mailbox.writeMessage(_msg, msg.sender);

        emit MailboxUpdated(msg.sender, recipient, msgCount+1, block.timestamp);
    }

    /**
     * @notice Writes a message to a dedicated Mailbox for (sender,recipient), hiding sender addr from a recipient
     * @param message The message to write
     * @param recipient Message recipient address
     */
    function writeMessageAnonymous(bytes calldata message, address recipient) external {
        UserMailbox storage mailbox = mailboxes[recipient];
        address anonSender = address(0);
        uint256 msgCount = mailbox.countMessagesFrom(anonSender);
        if (msgCount == MAX_MESSAGES_PER_MAILBOX) revert MailboxIsFull();

        Message memory _msg = Message({
            sender: anonSender,
            data: message,
            sentAt: block.timestamp
        });
        mailbox.writeMessage(_msg, anonSender);

        emit MailboxUpdated(anonSender, recipient, msgCount+1, block.timestamp);
    }

    /**
     * @notice Provides a message to its recipient from the specified sender
     * @param sender Sender address
     * @return msgId Message ID
     * @return data The message
     * @return sentAt Timestamp when the message was written
     */
    function readMessage(address sender) external view
        returns (bytes32 msgId, bytes memory data, uint256 sentAt) {
        
        UserMailbox storage mailbox = mailboxes[msg.sender];
        uint256 msgCount = mailbox.countMessagesFrom(sender);
        if (msgCount == 0) revert MailboxIsEmpty();
        (bytes32 _msgId, Message memory _msg) = mailbox.readMessageFrom(sender);
        msgId = _msgId;
        data = _msg.data;
        sentAt = _msg.sentAt;
    }

    /**
     * @notice Allows a recipient to read a message without specifying a sender.
     * Recipient is given next sender message after each read confirmation done by markMessageRead
     * @return msgId Message ID
     * @return sender address
     * @return data The message
     * @return sentAt Timestamp when the message was written
     */
    function readMessageNextSender() external view
        returns (bytes32 msgId, address sender, bytes memory data, uint256 sentAt) {
        UserMailbox storage mailbox = mailboxes[msg.sender];
        uint256 msgCount = mailbox.countSenders();
        if (msgCount == 0) revert MailboxIsEmpty();
        Message storage _msg;
        (msgId, _msg) = mailbox.readMessageNextSender();
        sender = _msg.sender;
        data = _msg.data;
        sentAt = _msg.sentAt;
    }

    /**
     * Marks a top message as read making the next message available for reading
     * @param msgId ID of the read message
     * @return moreMessages whether other message available from the same sender
     */
    function markMessageRead(bytes32 msgId) external returns (bool moreMessages) {
        UserMailbox storage mailbox = mailboxes[msg.sender];
        (bool exists, Message storage _msg) = mailbox.getMessage(msgId);
        if (!exists) revert MessageNotFound();
        uint256 msgCount = mailbox.countMessagesFrom(_msg.sender);
        emit MailboxUpdated(_msg.sender, msg.sender, msgCount-1, block.timestamp);
        return mailbox.markMessageRead(msgId);
    }
}
