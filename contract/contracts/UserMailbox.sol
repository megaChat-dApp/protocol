// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LinkedList, LinkedListInterface} from "./LinkedList.sol";

struct Message {
    address sender;
    uint256 sentAt;
    bytes data;
}
struct UserMailbox {
    mapping (bytes32 => Message) messages;
    mapping (bytes32 => LinkedList) orderedMessageLists;
    uint256 totalMessagesCount;
}

bytes32 constant NEXT_SENDER_LIST_ID = keccak256("nextSender");

using LinkedListInterface for LinkedList;

library UserMailboxInterface {
    function writeMessage(UserMailbox storage self, Message memory _msg, address sender) public {
        bytes32 messageId = keccak256(abi.encode(_msg));
        self.messages[messageId] = _msg;

        LinkedList storage list = self.orderedMessageLists[keccak256(abi.encode(sender))];
        list.init();
        list.insertTail(messageId);
        bool isFirstSenderMsg = list.size == 1;

        if (isFirstSenderMsg) {
            LinkedList storage nextSenderList = self.orderedMessageLists[NEXT_SENDER_LIST_ID];
            nextSenderList.init();
            nextSenderList.insertTail(messageId);
        }
    }

    function readMessageFrom(UserMailbox storage self, address sender) public view returns (bytes32, Message storage) {
        LinkedList storage list = self.orderedMessageLists[keccak256(abi.encode(sender))];
        bytes32 valHash = list.getHead();
        return (valHash, self.messages[valHash]);
    }

    function readMessageNextSender(UserMailbox storage self) public view returns (bytes32, Message storage) {
        LinkedList storage list = self.orderedMessageLists[NEXT_SENDER_LIST_ID];
        bytes32 valHash = list.getHead();
        return (valHash, self.messages[valHash]);
    }

    function getMessage(UserMailbox storage self, bytes32 msgId) internal view returns (bool exists, Message storage) {
        Message storage _msg = self.messages[msgId];
        return (_msg.sentAt != 0, _msg);
    }

    function countMessagesFrom(UserMailbox storage self, address sender) public view returns (uint256) {
        return self.orderedMessageLists[keccak256(abi.encode(sender))].size;
    }

    function countSenders(UserMailbox storage self) public view returns (uint256) {
        return self.orderedMessageLists[NEXT_SENDER_LIST_ID].size;
    }

    function markMessageRead(UserMailbox storage self, bytes32 messageId) public returns (bool moreMessages) {
        Message storage _msg = self.messages[messageId];
        LinkedList storage list = self.orderedMessageLists[keccak256(abi.encode(_msg.sender))];
        list.remove(messageId);
        self.messages[messageId].sentAt=0;

        LinkedList storage nextSenderList = self.orderedMessageLists[NEXT_SENDER_LIST_ID];
        nextSenderList.init();
        nextSenderList.remove(messageId);
        if(list.size>0) {
            nextSenderList.insertTail(list.getHead());
        }
        return list.size > 0;
    }
}
