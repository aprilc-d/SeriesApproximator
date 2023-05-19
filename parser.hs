{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}
{-# HLINT ignore "Use camelCase" #-}
{-# HLINT ignore "Redundant if" #-}
{-# HLINT ignore "Redundant bracket" #-}
{-# HLINT ignore "Use null" #-}
{-# HLINT ignore "Use :" #-}
{-# LANGUAGE BlockArguments #-}
{-# HLINT ignore "Use list literal" #-}
{-# OPTIONS_GHC -Wno-overlapping-patterns #-}
{-# HLINT ignore "Use guards" #-}
{-# HLINT ignore "Avoid lambda" #-}

import Data.String
import Data.List
import System.Environment
import System.Exit
import System.IO
import Distribution.Simple.Command (OptDescr(BoolOpt))

import Stack
import Expression
import Tree
import StringFunctions

main :: IO ()
main =
  do {
    args <- getArgs
    ; if length args == 0 then print ("please put in an argument")
    else print (
      --order_of_operations (latex_to_list (combine args)) [] (accumulate_ops (latex_to_list (combine args)))
      map (\a -> precedence (find_corresponding a)) (accumulate_ops (latex_to_list (combine args)))
        --latex_to_list (combine args)
        )
    
  }


-- constants for parsing --

special_chars :: [Char]
special_chars = ['/', '+', ' ', '-', '*', '\\', '^', '_', '{', '}', '[', ']', '(', ')', '!']

brackets :: [Char]
brackets = ['{', '}', '[', ']', '(', ')']

brackets_string :: [String]
brackets_string = ["{", "}", "[", "]", "(", ")"]

front_brackets :: [String]
front_brackets = ["{", "[", "("]

back_brackets :: [String]
back_brackets = ["}", "]", ")"]

operators :: [Char]
operators = ['+', '-', '*', '/', '^', '!']

string_operators :: [String]
string_operators = ["\\frac", "+", "-", "/", "*", "\\times", "^", "!"]

same_set :: String -> String -> Bool
same_set s1 s2 =
 if ((string_equality s1 "{") && (string_equality s2 "}")) ||
  ((string_equality s1 "(") && (string_equality s2 ")")) ||
  ((string_equality s1 "[") && (string_equality s2 "]"))
  then True
  else False

reverse_bracket :: String -> String
reverse_bracket s =
  if (string_equality s "{") then "}"
  else
    if (string_equality s "(") then ")"
    else
      if (string_equality s "[") then "]"
      else error "invalid arguement"

check_for_front_brk :: [String] -> Bool
check_for_front_brk [] = False
check_for_front_brk (x:xs) =
  if check_possibilities x front_brackets then True
  else check_for_front_brk xs

accumulate_ops :: [String] -> [String]
accumulate_ops [] = []
accumulate_ops (x:xs) =
  if check_possibilities x string_operators then x:(accumulate_ops xs)
  else accumulate_ops xs

uniform_list :: [Int] -> Int -> Bool
uniform_list [] n = True
unifrom_list (x:xs) n = if x == n then unifrom_list xs n else False




add_front_brks :: [String] -> Int -> [String]
add_front_brks l 0 = l
add_front_brks (l) n = add_front_brks ("(":l) (n-1)

add_back_brks_equal_prec :: [String] -> [String] -> [String]
add_back_brks_equal_prec [] [] = []
add_back_brks_equal_prec [] _ = error "invalid arguments"
add_back_brks_equal_prec input [] = input 
add_back_brks_equal_prec (x:xs) (op:ops) = 
  if string_equality op x then ( 
    case x of 
      "\\frac" -> []
      "+" -> x:")":(add_back_brks_equal_prec xs ops)
      "-" -> x:")":(add_back_brks_equal_prec xs ops) 
      "/" -> x:")":(add_back_brks_equal_prec xs ops) 
      "*" -> x:")":(add_back_brks_equal_prec xs ops) 
      "\\times" -> x:")":(add_back_brks_equal_prec xs ops) 
      "^" -> x:")":(add_back_brks_equal_prec xs ops)
      "!" -> x:")":(add_back_brks_equal_prec xs ops)
    )

    else add_back_brks_equal_prec xs ops

-- parsing techniques --

latex_to_list_helper :: String -> [String] -> [String]
latex_to_list_helper s l =
  case s of
  [] -> l
  (x:xs) ->
    if length l /= 0 && string_equality (last l) "" then (

      if x `elem` special_chars then (

      if (x `elem` operators || x `elem` brackets) then
        latex_to_list_helper xs ((init l) ++ [append_char x (last l)]++[""])

      else
        if x == ' ' then latex_to_list_helper xs l
        else latex_to_list_helper xs ((init l) ++ [(append_char '\\' (last l))])
    )
    else
      latex_to_list_helper xs ((init l) ++ [(append_char x (last l))])
    )

    else (
    if x `elem` special_chars then (

        if (x `elem` operators || x `elem` brackets) then
          latex_to_list_helper xs (l ++ [char_to_string x]++[""])

        else (
          if x == ' ' then latex_to_list_helper xs (l ++ [""])
          else latex_to_list_helper xs (l ++ ["\\"])
        )
      )

      else (
        if length l == 0
          then latex_to_list_helper xs ([(char_to_string x)])
          else (
            if string_equality (last l) "" then
              latex_to_list_helper xs (init l ++ [(char_to_string x)])
              else
                latex_to_list_helper xs (init l ++ [(append_char x (last l))])
          )
    )
    )

latex_to_list :: String -> [String]
latex_to_list s = latex_to_list_helper s []

-- uses a stack to ensure that the order of brackets is valid, otherwise the expression cannot be evaluated
brackets_valid :: [String] -> Stack String -> Bool
brackets_valid strings stack =
  case strings of
    [] ->
      case stack of
        EmptyStack -> True
        S _ _-> False
    x:xs ->
      if check_possibilities x brackets_string then
        case pre_pop stack of
          Nothing -> if check_possibilities x back_brackets then False else brackets_valid xs (push x stack)
          Just (head) ->
            if same_set head x then
              brackets_valid (xs) (pop stack)
            else (
              if not (check_possibilities x back_brackets) then brackets_valid (xs) (push x stack)
              else False
            )
        else
          brackets_valid xs stack

order_of_operations :: [String] -> String -> [String] -> [String]
order_of_operations [] current_brk ops = []
order_of_operations input current_brk ops =

  -- no internal brackets 
  if not (check_for_front_brk input) then

    -- if all have same precedence add brackets from left to right
    if 
      uniform_list 
        (map (\a -> precedence (find_corresponding a)) (accumulate_ops input)) 
        (head (map (\a -> precedence (find_corresponding a)) (accumulate_ops input)))

      then
        --adding front brackets equal to the number of operators
        add_back_brks_equal_prec 
        (add_front_brks input (length (accumulate_ops input)))
        (accumulate_ops input)

    else []


  else []


convert_to_Exp :: [String] -> Exp -> [Exp] -> [Exp] -> [Exp]
convert_to_Exp s op_cache input_cache sc =
  case s of
    [] -> sc
    x:xs ->
      if (check_possibilities x string_operators)
        then (
          if correct_args (find_corresponding x) == length input_cache then
              sc else sc )
        else sc