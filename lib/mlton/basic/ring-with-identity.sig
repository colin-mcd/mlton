(* Copyright (C) 1999-2002 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 *
 * MLton is released under the GNU General Public License (GPL).
 * Please see the file MLton-LICENSE for license information.
 *)
signature RING_WITH_IDENTITY_STRUCTS = 
   sig
      include RING
	 
      val one: t
   end

signature RING_WITH_IDENTITY = 
   sig
      include RING_WITH_IDENTITY_STRUCTS

      val ^ : t * Pervasive.Int.int -> t
      val ^^ : t * Pervasive.IntInf.int -> t

      val add1: t -> t
      val dec: t ref -> unit
      (* fromInt n = 1 + ... + 1, n times. *)
      val fromInt: Pervasive.Int.int -> t
      val fromIntInf: Pervasive.IntInf.int -> t
      val inc: t ref -> unit
      val negOne: t
      val power: (t * Pervasive.Int.int) list -> t (* simultaneous exponentiation *)
      val powerInf: (t * Pervasive.IntInf.int) list -> t
      val prod: t list -> t
      val sub1: t -> t
      val three: t
      val two: t
   end
