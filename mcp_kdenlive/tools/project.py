"""Project-level tools: info, save, load, render."""

from __future__ import annotations

from mcp.server.fastmcp import Context


def register(mcp, helpers):

    @mcp.tool()
    def get_project_info(ctx: Context) -> str:
        """Get current project settings: name, fps, resolution, path, track counts, duration."""
        try:
            proj = helpers.get_project(ctx)
            tl = proj.GetCurrentTimeline()
            fps = proj.GetFps()
            w, h = proj.GetResolution()
            name = proj.GetName()
            path = proj.GetProjectPath()

            video_tracks = tl.GetTrackCount("video") if tl else 0
            audio_tracks = tl.GetTrackCount("audio") if tl else 0
            duration = tl.GetTotalDuration() if tl else 0
            dur_tc = helpers.format_tc(duration, fps) if tl else "00:00:00:00"

            lines = [
                f"**Project:** {name}",
                f"**Path:** {path}",
                f"**FPS:** {fps}",
                f"**Resolution:** {w}x{h}",
                f"**Video tracks:** {video_tracks}",
                f"**Audio tracks:** {audio_tracks}",
                f"**Duration:** {dur_tc} ({duration} frames)",
            ]
            return "\n".join(lines)
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def new_project(ctx: Context, name: str = "") -> str:
        """Create a new empty Kdenlive project.

        Args:
            name: Project name (optional).
        """
        try:
            resolve = helpers.get_resolve(ctx)
            result = resolve._dbus.new_project(name)
            return f"Created new project '{name}'" if result else "ERROR: Could not create project"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def open_project(ctx: Context, file_path: str) -> str:
        """Open a Kdenlive project file (with retry logic).

        Unlike load_project, this uses the lower-level D-Bus scriptOpenProject
        method which includes automatic retry for robustness.

        Args:
            file_path: Absolute path to .kdenlive file.
        """
        try:
            resolve = helpers.get_resolve(ctx)
            ok = resolve._dbus.open_project(file_path)
            if not ok:
                return f"ERROR: Could not open {file_path}"
            return f"Opened project: {file_path}"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def set_project_profile(ctx: Context, width: int, height: int,
                            fps_num: int, fps_den: int = 1) -> str:
        """Change project resolution and frame rate.

        Args:
            width: Frame width in pixels (e.g. 1920).
            height: Frame height in pixels (e.g. 1080).
            fps_num: FPS numerator (e.g. 25 for 25fps, 30000 for 29.97fps).
            fps_den: FPS denominator (default 1; use 1001 for 29.97/59.94fps).
        """
        try:
            resolve = helpers.get_resolve(ctx)
            ok = resolve._dbus.set_project_profile(width, height, fps_num, fps_den)
            if not ok:
                return f"ERROR: Could not set profile {width}x{height} {fps_num}/{fps_den}fps"
            fps = fps_num / fps_den
            return f"Profile set to {width}x{height} @ {fps:.2f}fps"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def save_project(ctx: Context, file_path: str = "") -> str:
        """Save the current project. If file_path is given, does Save As.

        Args:
            file_path: Optional path for Save As. Empty string saves in place.
        """
        try:
            proj = helpers.get_project(ctx)
            if file_path:
                ok = proj.SaveAs(file_path)
                return f"Saved to {file_path}" if ok else "ERROR: SaveAs failed"
            else:
                ok = proj.Save()
                return f"Saved to {proj.GetProjectPath()}" if ok else "ERROR: Save failed"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def render_video(ctx: Context, output_path: str = "",
                     preset_name: str = "", in_frame: int = -1,
                     out_frame: int = -1, params: dict[str, str] | None = None) -> str:
        """Start rendering the timeline to a video file.

        Args:
            output_path: Output file path. If empty, uses project default.
            preset_name: Render preset name (use get_render_presets to list).
                         If empty, uses the simple render path.
            in_frame: Start frame (-1 = project start).
            out_frame: End frame (-1 = project end).
            params: Optional dict of FFmpeg/MLT parameter overrides
                    (e.g. {"crf": "19", "preset": "fast", "b:v": "5000k"}).
        """
        try:
            resolve = helpers.get_resolve(ctx)
            if preset_name or params or in_frame >= 0 or out_frame >= 0:
                # Advanced render with parameters
                if not output_path:
                    return "ERROR: output_path required for parametric render"
                ok = resolve._dbus.render_with_params(
                    output_path, preset_name, in_frame, out_frame, params
                )
                if not ok:
                    return "ERROR: Render failed (check preset name and parameters)"
                return f"Render started -> {output_path}"
            else:
                if output_path:
                    resolve._dbus.render(output_path)
                else:
                    proj = helpers.get_project(ctx)
                    proj.StartRendering()
                return "Render started" + (f" -> {output_path}" if output_path else "")
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def get_render_presets(ctx: Context) -> str:
        """List all available render presets (codec/format profiles).

        Returns a newline-separated list of preset names that can be
        used with render_video's preset_name parameter.
        """
        try:
            resolve = helpers.get_resolve(ctx)
            presets = resolve._dbus.get_render_presets()
            if not presets:
                return "No render presets found."
            return f"{len(presets)} presets:\n" + "\n".join(f"- {p}" for p in presets)
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def get_render_jobs(ctx: Context) -> str:
        """Get list of render jobs with status and progress.

        Returns a markdown table showing each job's output path, status,
        progress percentage, and current frame.
        """
        try:
            resolve = helpers.get_resolve(ctx)
            jobs = resolve._dbus.get_render_jobs()
            if not jobs:
                return "No render jobs."
            lines = ["| path | status | progress | frame |",
                      "|------|--------|----------|-------|"]
            for j in jobs:
                lines.append(
                    f"| {j.get('path', '?')} | {j.get('status', '?')} "
                    f"| {j.get('progress', 0)}% | {j.get('frame', 0)} |"
                )
            return "\n".join(lines)
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def abort_render_job(ctx: Context, output_path: str) -> str:
        """Abort a running render job.

        Args:
            output_path: The output file path of the job to abort
                         (as shown in get_render_jobs).
        """
        try:
            resolve = helpers.get_resolve(ctx)
            ok = resolve._dbus.abort_render_job(output_path)
            if ok:
                return f"Abort signal sent for: {output_path}"
            return f"ERROR: Could not abort render job {output_path}"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def create_render_preset(ctx: Context, name: str, group_id: str, params: str,
                             extension: str, v_bitrate: str = "", v_quality: str = "",
                             a_bitrate: str = "", a_quality: str = "") -> str:
        """Create a custom render preset (e.g. a specific YouTube or vertical export profile).

        Once created, the preset shows up in get_render_presets and can be used
        as render_video's preset_name.

        Args:
            name: Preset display name.
            group_id: Group/category the preset appears under in the render dialog
                      (e.g. "customcategory").
            params: MLT consumer parameter string (e.g. "vcodec=libx264 acodec=aac crf=18").
            extension: Output file extension without dot (e.g. "mp4").
            v_bitrate: Video bitrate (e.g. "8000k"), leave empty if using crf/quality in params.
            v_quality: Video quality/CRF value as string, leave empty if not applicable.
            a_bitrate: Audio bitrate (e.g. "192k"), leave empty to use params default.
            a_quality: Audio quality value as string, leave empty if not applicable.
        """
        try:
            resolve = helpers.get_resolve(ctx)
            saved_name = resolve._dbus.create_render_preset(
                name, group_id, params, extension, v_bitrate, v_quality, a_bitrate, a_quality
            )
            if not saved_name:
                return f"ERROR: Could not create render preset '{name}' (empty name or params?)"
            return f"Created render preset: {saved_name}"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def delete_render_preset(ctx: Context, name: str) -> str:
        """Delete a custom render preset by name.

        Args:
            name: Preset name (as shown in get_render_presets).
        """
        try:
            resolve = helpers.get_resolve(ctx)
            ok = resolve._dbus.delete_render_preset(name)
            if not ok:
                return f"ERROR: Could not delete render preset '{name}' (not found?)"
            return f"Deleted render preset: {name}"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def create_project_profile(ctx: Context, width: int, height: int,
                               fps_num: int, fps_den: int = 1, description: str = "",
                               sample_aspect_num: int = 1, sample_aspect_den: int = 1,
                               colorspace: int = 709, progressive: bool = True) -> str:
        """Create a custom project profile, e.g. a 9:16 vertical profile for
        Reels/TikTok/Shorts (width=1080, height=1920, fps_num=30).

        Reuses a matching existing profile automatically if the same dimensions
        and framerate were already registered. The returned path is a profile
        identifier — pass it to open_project/set_project_profile-style workflows
        or use it when creating a new sequence that needs this aspect ratio.

        Args:
            width: Frame width in pixels (e.g. 1080 for vertical, 1920 for horizontal).
            height: Frame height in pixels (e.g. 1920 for vertical, 1080 for horizontal).
            fps_num: FPS numerator (e.g. 30 for 30fps, 30000 for 29.97fps).
            fps_den: FPS denominator (default 1; use 1001 for 29.97/59.94fps).
            description: Human-readable name; auto-generated from dimensions if empty.
            sample_aspect_num: Pixel aspect ratio numerator (1 for square pixels — almost always correct).
            sample_aspect_den: Pixel aspect ratio denominator (1 for square pixels — almost always correct).
            colorspace: 709 (HD/most social platforms), 601 (SD), or 2020 (HDR).
            progressive: True for progressive scan (almost always what you want).
        """
        try:
            resolve = helpers.get_resolve(ctx)
            path = resolve._dbus.create_project_profile(
                description, width, height, fps_num, fps_den,
                sample_aspect_num, sample_aspect_den, colorspace, progressive
            )
            if not path:
                return f"ERROR: Could not create profile {width}x{height} @ {fps_num}/{fps_den}fps (invalid dimensions?)"
            return f"Profile created/matched: {path}"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def get_project_notes(ctx: Context) -> str:
        """Get the current project's notes (Kdenlive's Notes panel)."""
        try:
            resolve = helpers.get_resolve(ctx)
            notes = resolve._dbus.get_project_notes()
            return notes if notes else "(no notes)"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def set_project_notes(ctx: Context, text: str) -> str:
        """Append text to the current project's notes.

        Kdenlive's scripting API has no "replace all" for notes — this always
        appends a new note. Call get_project_notes first if you need to see
        what's already there before adding more.

        Args:
            text: Text to append as a new note.
        """
        try:
            resolve = helpers.get_resolve(ctx)
            ok = resolve._dbus.set_project_notes(text)
            if not ok:
                return "ERROR: Could not add project note (no project open?)"
            return "Note added to project"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def list_backups(ctx: Context) -> str:
        """List backup file paths for the current project, newest first.

        Kdenlive auto-saves backups to the project's temp folder. Use
        restore_backup with one of these paths to recover from one.
        """
        try:
            resolve = helpers.get_resolve(ctx)
            backups = resolve._dbus.list_backups()
            if not backups:
                return "No backups found."
            return f"{len(backups)} backups (newest first):\n" + "\n".join(f"- {b}" for b in backups)
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def restore_backup(ctx: Context, backup_path: str) -> str:
        """Open a backup file, replacing the current project in the editor.

        This does not prompt for confirmation on unsaved changes — warn the
        user about losing unsaved work before calling this.

        Args:
            backup_path: One of the paths returned by list_backups.
        """
        try:
            resolve = helpers.get_resolve(ctx)
            ok = resolve._dbus.restore_backup(backup_path)
            if not ok:
                return f"ERROR: Could not restore backup {backup_path}"
            return f"Restored backup: {backup_path}"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def set_playback_speed(ctx: Context, speed: float) -> str:
        """Set preview playback speed. Use to play at 2x, 0.5x, etc.

        Args:
            speed: Speed multiplier. 1.0 = normal, 2.0 = 2x forward,
                   -1.0 = 1x rewind, 0.5 = half speed. 0 = toggle play/pause.
        """
        try:
            resolve = helpers.get_resolve(ctx)
            ok = resolve._dbus.set_playback_speed(speed)
            if not ok:
                return f"ERROR: Could not set playback speed {speed}x"
            if speed == 0:
                return "Toggled play/pause"
            return f"Playback speed set to {speed}x"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def load_project(ctx: Context, file_path: str) -> str:
        """Load a Kdenlive project file.

        Args:
            file_path: Absolute path to .kdenlive file.
        """
        try:
            resolve = helpers.get_resolve(ctx)
            pm = resolve.GetProjectManager()
            proj = pm.LoadProject(file_path)
            if proj is None:
                return f"ERROR: Could not load {file_path}"
            fps = proj.GetFps()
            w, h = proj.GetResolution()
            name = proj.GetName()
            return f"Loaded '{name}' ({fps}fps, {w}x{h})"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def get_project_duration(ctx: Context) -> str:
        """Get total timeline duration."""
        try:
            resolve = helpers.get_resolve(ctx)
            fps = helpers.get_fps(ctx)
            frames = int(resolve._dbus.get_project_duration())
            tc = helpers.format_tc(frames, fps)
            return f"Timeline duration: {tc} ({frames} frames)"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def get_project_color_space(ctx: Context) -> str:
        """Get project color space setting."""
        try:
            resolve = helpers.get_resolve(ctx)
            cs = resolve._dbus.get_project_color_space()
            return f"Color space: {cs}"
        except Exception as e:
            return f"ERROR: {e}"

    @mcp.tool()
    def set_project_color_space(ctx: Context, color_space: str) -> str:
        """Set project color space.

        Args:
            color_space: Color space identifier (e.g. "709", "2020", "smpte240m").
        """
        try:
            resolve = helpers.get_resolve(ctx)
            ok = resolve._dbus.set_project_color_space(color_space)
            if not ok:
                return f"ERROR: Could not set color space to {color_space}"
            return f"Color space set to {color_space}"
        except Exception as e:
            return f"ERROR: {e}"
