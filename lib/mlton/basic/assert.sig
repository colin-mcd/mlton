(* Copyright (C) 1999-2002 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 *
 * MLton is released under the GNU General Public License (GPL).
 * Please see the file MLton-LICENSE for license information.
 *)
signature ASSERT =
   sig
      val assert: string * (unit -> bool) -> unit
      val assertFun:
	 string
	 * ('a -> 'b)
	 * ('a -> bool * ('b -> bool))
	 -> 'a -> 'b
      val assertFun2:
	 string
	 * ('a -> 'b -> 'c)
	 * ('a -> bool * ('b -> (bool * ('c -> bool))))
	 -> 'a -> 'b -> 'c
      val debug: bool
      val fail: string -> 'a
   end
