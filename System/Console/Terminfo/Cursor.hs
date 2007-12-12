-- |
-- Maintainer  : judah.jacobson@gmail.com
-- Stability   : experimental
-- Portability : portable (FFI)
--
-- | This module provides capabilities for moving the cursor on the terminal. -}
module System.Console.Terminfo.Cursor(
                        -- * Terminal dimensions
                        -- | Get the default size of the terminal.  For
                        -- resizeable terminals (e.g., @xterm@), these may not
                        -- correspond to the actual dimensions.
                        termLines, termColumns,
                        -- * Scrolling
                        carriageReturn,
                        newline,
                        scrollForward,
                        scrollReverse,
                        -- * Relative cursor movements
                        -- | The following functions for cursor movement will
                        -- combine the more primitive capabilities.  For example,
                        -- 'moveDown' may use either 'cursorDown' or
                        -- 'cursorDown1' depending on the parameter and which of
                        -- @cud@ and @cud1@ are defined.
                        moveDown, moveLeft, moveRight, moveUp,
                        
                        -- ** Primitive movement capabilities
                        -- | These capabilities correspond directly to @cub@, @cud@,
                        -- @cub1@, @cud1@, etc.
                        cursorDown1, 
                        cursorLeft1,
                        cursorRight1,
                        cursorUp1, 
                        cursorDown, 
                        cursorLeft,
                        cursorRight,
                        cursorUp, 
                        -- * Absolute cursor movements
                        cursorAddress,
                        Point(..),
                        rowAddress,
                        columnAddress
                        ) where

import System.Console.Terminfo.Base
import Control.Monad

termLines, termColumns :: Capability Int
termLines = tiGetNum "lines"
termColumns = tiGetNum "columns"

{--
On many terminals, the @cud1@ ('cursorDown1') capability is the line feed 
character '\n'.  However, @stty@ settings may cause that character to have
other effects than intended; e.g. ONLCR turns LF into CRLF, and as a result 
@cud1@ will always move the cursor to the first column of the next line.  

Looking at the source code of curses (lib_mvcur.c) and other similar programs, 
they use @cud@ instead of @cud1@ if it's '\n' and ONLCR is turned on.  

Since there's no easy way to check for ONLCR at this point, I've just made
cursorDown1 always use @cud@.

Note the same problems apply to @ind@, but I think there's less of an
expectation that scrolling down will keep the same column.  
Suggestions are welcome.
--}
cursorDown1, cursorLeft1,cursorRight1,cursorUp1 :: Capability TermOutput
cursorDown1 = fmap ($1) cursorDown
cursorLeft1 = tiGetOutput1 "cub1"
cursorRight1 = tiGetOutput1 "cuf1"
cursorUp1 = tiGetOutput1 "cuu1"

cursorDown, cursorLeft, cursorRight, cursorUp :: Capability (Int -> TermOutput)
cursorDown = tiGetOutput1 "cud"
cursorLeft = tiGetOutput1 "cub"
cursorRight = tiGetOutput1 "cuf"
cursorUp = tiGetOutput1 "cuu"

cursorHome, cursorToLL :: Capability TermOutput
cursorHome = tiGetOutput1 "home"
cursorToLL = tiGetOutput1 "ll"


-- Movements are built out of parametrized and unparam'd movement
-- capabilities.
-- todo: more complicated logic like ncurses does.
move single param = let
        tryBoth = do
                    s <- single
                    p <- param
                    return $ \n -> case n of
                        0 -> mempty
                        1 -> s
                        n -> p n
        manySingle = do
                        s <- single
                        return $ \n -> mconcat $ replicate n s
        in tryBoth `mplus` param `mplus` manySingle

moveLeft, moveRight, moveUp, moveDown :: Capability (Int -> TermOutput)
moveLeft = move cursorLeft1 cursorLeft
moveRight = move cursorRight1 cursorRight
moveUp = move cursorUp1 cursorUp
moveDown = cursorDown -- see notes on @cud1@ above

-- | The @cr@ capability, which moves the cursor to the first column of the
-- current line.
carriageReturn :: Capability TermOutput
carriageReturn = tiGetOutput1 "cr"

-- | The @nel@ capability, which moves the cursor to the first column of
-- the next line.  It behaves like a carriage return followed by a line feed.
--
-- If @nel@ is not defined, this may be built out of other capabilities.
newline :: Capability TermOutput
newline = tiGetOutput1 "nel" 
    `mplus` (liftM2 mappend carriageReturn 
                            (scrollForward `mplus` tiGetOutput1 "cud1"))
        -- Note it's OK to use cud1 here, despite the stty problem referenced 
        -- above, because carriageReturn already puts us on the first column.

scrollForward, scrollReverse :: Capability TermOutput
scrollForward = tiGetOutput1 "ind"
scrollReverse = tiGetOutput1 "ri"


data Point = Point {row, col :: Int}

cursorAddress :: Capability (Point -> TermOutput)
cursorAddress = fmap (\g p -> g (row p) (col p)) $ tiGetOutput1 "cup"

columnAddress, rowAddress :: Capability (Int -> TermOutput)
columnAddress = tiGetOutput1 "hpa"
rowAddress = tiGetOutput1 "vpa"


