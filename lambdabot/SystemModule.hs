{-# OPTIONS -fglasgow-exts #-}
module SystemModule where

-- 	$Id: SystemModule.hs,v 1.4 2003/07/25 13:19:22 eleganesh Exp $

import IRC
import Util
import qualified Map as M

import Control.Monad.State
import Control.Monad.Reader

newtype SystemModule = SystemModule ()

systemModule :: SystemModule
systemModule = SystemModule ()

instance Module SystemModule () where
    moduleName   _ = return "system"
    moduleHelp _ _ = return "system: irc commands"
    moduleSticky _ = False
    commands     _ = return ["listchans", "listmodules", "listcommands",
			     "join", "leave", "part", "msg", "quit",
			     "reconnect", "echo"]
    process      _ msg target cmd rest = doSystem msg target cmd rest

doSystem :: MonadIRC m => IRCMessage -> String -> [Char] -> [Char] -> m ()
doSystem msg target cmd rest
 = do
   s <- liftIRC get
   case cmd of
            "listchans"
                -> ircPrivmsg target $ "I am on these channels: "
                   ++ show (M.keys (ircChannels s))
            "listmodules"
                -> ircPrivmsg target $
		     "I have the following modules installed: "
                     ++ show (M.keys (ircModules s))
            "listcommands"
                -> if null rest then list_all_commands s target
                   else list_module_commands s target rest
            "join"
                -> checkPrivs msg target (ircJoin rest)
            "leave"
                -> checkPrivs msg target (ircPart rest)
            "part"
                -> checkPrivs msg target (ircPart rest)
            "msg"
                -> checkPrivs msg target
                     (let (tgt, txt) = breakOnGlue " " rest
                      in ircPrivmsg tgt (dropWhile (==' ') txt))
            "quit"
                -> checkPrivs msg target $
                          ircQuit $ if rest=="" then "request" else rest
            "reconnect"
                -> checkPrivs msg target $
                          ircReconnect $ if rest=="" then "request" else rest
            "echo"
                -> ircPrivmsg target $ concat ["echo; msg:", show msg,
					       " rest:", show rest]

            _unknowncmd
                -> ircPrivmsg target $ concat ["excuse me? ", show msg,
					       show rest]

list_all_commands :: MonadIRC m => IRCRWState -> String -> m ()
list_all_commands state target
  = ircPrivmsg target $ "I react to the following commands: "
    ++ show (M.keys (ircCommands state))

list_module_commands :: MonadIRC m => IRCRWState -> String -> String -> m ()
list_module_commands state target modname
  = case M.lookup modname (ircModules state) of
       Just (ModuleRef m ref) -> do
         cmds <- liftLB $ commands m `runReaderT` ref
         ircPrivmsg target $ concat ["Module ", modname,
            " provides the following commands: ", show cmds]
       Nothing -> ircPrivmsg target $
                    "No module \""++modname++"\" loaded"
