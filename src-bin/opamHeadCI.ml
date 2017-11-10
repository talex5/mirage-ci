(*---------------------------------------------------------------------------
   Copyright (c) 2017 Anil Madhavapeddy. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   %%NAME%% %%VERSION%%
  ---------------------------------------------------------------------------*)

open !Astring
open Datakit_ci
open Datakit_github
module DO = Docker_ops

module Builder = struct

  open Term.Infix

  let label = "opamHeadCI"
  let docker_t = DO.v ~logs ~label ~jobs:24 ()
  let opam_t = Opam_build.v ~logs ~label
  let opam_bulk_t = Opam_bulk_build.v ~label ~logs
  let opam_bulk_diff_t = Opam_bulk_build_diff.v ~label ~logs

  let packages_of_repo {Repo.user;repo} =
    match user, repo with
    | "ocaml","opam-repository" -> ["async";"coq";"mirage";"datakit"]
    | "janestreet","opam-repository" -> ["jane-street-tests"]
    | _ -> ["ocamlfind"]

  let repo_builder ~revdeps ~typ ~opam_version target =
    let packages = packages_of_repo (Target.repo target) in
    let t = 
      Opam_build.run ~packages ~distro:"ubuntu-16.04" ~ocaml_version:"4.02.1" ~remotes:[] ~typ ~opam_version opam_t >>= fun df ->
      let hum = "Acceptance tests" in
      Docker_build.run docker_t.Docker_ops.build_t ~pull:true ~hum df >>= fun _ ->
      Term.return "success" in
    "acceptance", t

  let run_phases typ target =
    let tests ~revdeps = [
      (repo_builder ~revdeps:false ~typ ~opam_version:`V1 target);
      (repo_builder ~revdeps ~typ ~opam_version:`V2 target) ]
    in
    match Target.id target with
    |`Ref ["heads";"master"] -> tests ~revdeps:false 
    |`Ref _  |`PR _ -> []

  let tests = [
    Config.project ~id:"ocaml/opam-repository" (run_phases `Full_repo);
  ]
end

(* Command-line parsing *)

let web_config =
  Web.config
    ~name:"opam-repo-ci"
    ~can_read:ACL.(everyone)
    ~can_build:ACL.(everyone)
    ~state_repo:(Uri.of_string "https://github.com/ocaml/ocaml-ci.logs")
    ()

let () =
  run (Cmdliner.Term.pure (Config.v ~web_config ~projects:Builder.tests))

(*---------------------------------------------------------------------------
   Copyright (c) 2016 Anil Madhavapeddy
   Copyright (c) 2016 Thomas Leonard

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
