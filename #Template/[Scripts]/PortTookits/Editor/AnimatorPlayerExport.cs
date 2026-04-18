using System;
using System.IO;
using System.Globalization;
using System.Text;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEditor.Animations;
using UnityEngine;
using MaxIceFlameTemplate.Animations;

public static class AnimatorPlayerExport
{
	[MenuItem("Tools/Export AnimatorPlayer (Current Scene)")]
	public static void ExportCurrentScene()
	{
		string folder = EditorUtility.OpenFolderPanel("Export AnimatorPlayer", "", "");
		if (string.IsNullOrEmpty(folder))
			return;

		var scene = EditorSceneManager.GetActiveScene();
		if (!scene.IsValid())
		{
			Debug.LogWarning("Active scene is not valid.");
			return;
		}

		int exported = 0;
		foreach (var root in scene.GetRootGameObjects())
		{
			var comps = root.GetComponentsInChildren<AnimatorPlayer>(true);
			foreach (var comp in comps)
			{
				int componentIndex = GetComponentIndex(comp);
				string hierarchyPath = GetHierarchyPath(comp.transform);
				string fileName = SanitizeFileName(hierarchyPath.Replace("/", "_")) + "__" + componentIndex + ".mpm";
				string filePath = Path.Combine(folder, fileName);

				var animatorNames = new List<string>();
				var controllerNames = new List<string>();
				var motionNames = new List<string>();
				var motionSeen = new HashSet<string>();

				foreach (var animator in comp.Animators)
				{
					if (animator == null)
						continue;

					animatorNames.Add(animator.name);
					string controllerName = animator.runtimeAnimatorController != null ? animator.runtimeAnimatorController.name : "";
					controllerNames.Add(controllerName);

					var controller = ResolveController(animator.runtimeAnimatorController);
					if (controller != null)
					{
						AddClips(controller, motionNames, motionSeen);
						AddMotions(controller, motionNames, motionSeen);
					}
				}

				var sb = new StringBuilder();
				sb.AppendLine("hierarchy_path=" + hierarchyPath);
				sb.AppendLine("component_index=" + componentIndex.ToString(CultureInfo.InvariantCulture));
				sb.AppendLine("local_pos=" + Vec3(comp.transform.localPosition));
				sb.AppendLine("local_rot=" + Vec3(comp.transform.localEulerAngles));
				sb.AppendLine("local_scale=" + Vec3(comp.transform.localScale));

				var box = comp.GetComponent<BoxCollider>();
				if (box != null)
				{
					sb.AppendLine("box_center=" + Vec3(box.center));
					sb.AppendLine("box_size=" + Vec3(box.size));
				}
				else
				{
					sb.AppendLine("box_center=0,0,0");
					sb.AppendLine("box_size=0,0,0");
					Debug.LogWarning("Missing BoxCollider on " + hierarchyPath);
				}

				sb.AppendLine("animator_count=" + animatorNames.Count.ToString(CultureInfo.InvariantCulture));
				for (int i = 0; i < animatorNames.Count; i++)
				{
					sb.AppendLine("animator_" + i + "_name=" + animatorNames[i]);
					string ctrl = i < controllerNames.Count ? controllerNames[i] : "";
					sb.AppendLine("controller_" + i + "_name=" + ctrl);
				}

				sb.AppendLine("motion_count=" + motionNames.Count.ToString(CultureInfo.InvariantCulture));
				for (int i = 0; i < motionNames.Count; i++)
				{
					sb.AppendLine("motion_" + i + "_name=" + motionNames[i]);
				}

				File.WriteAllText(filePath, sb.ToString(), Encoding.UTF8);
				exported++;
			}
		}

		if (exported == 0)
			Debug.LogError("No AnimatorPlayer components found in current scene.");
		else
			Debug.Log("Exported " + exported + " AnimatorPlayer components to: " + folder);
	}

	private static AnimatorController ResolveController(RuntimeAnimatorController controller)
	{
		if (controller == null)
			return null;
		var direct = controller as AnimatorController;
		if (direct != null)
			return direct;
		var overrideCtrl = controller as AnimatorOverrideController;
		if (overrideCtrl != null)
			return overrideCtrl.runtimeAnimatorController as AnimatorController;
		return null;
	}

	private static void AddClips(AnimatorController controller, List<string> motionNames, HashSet<string> seen)
	{
		foreach (var clip in controller.animationClips)
		{
			if (clip == null)
				continue;
			AddName(clip.name, motionNames, seen);
		}
	}

	private static void AddMotions(AnimatorController controller, List<string> motionNames, HashSet<string> seen)
	{
		foreach (var layer in controller.layers)
		{
			AddStateMachine(layer.stateMachine, motionNames, seen);
		}
	}

	private static void AddStateMachine(AnimatorStateMachine machine, List<string> motionNames, HashSet<string> seen)
	{
		foreach (var childState in machine.states)
		{
			AddMotion(childState.state.motion, motionNames, seen);
		}
		foreach (var child in machine.stateMachines)
		{
			AddStateMachine(child.stateMachine, motionNames, seen);
		}
	}

	private static void AddMotion(Motion motion, List<string> motionNames, HashSet<string> seen)
	{
		if (motion == null)
			return;
		AddName(motion.name, motionNames, seen);
		var tree = motion as BlendTree;
		if (tree == null)
			return;
		foreach (var child in tree.children)
		{
			AddMotion(child.motion, motionNames, seen);
		}
	}

	private static void AddName(string name, List<string> motionNames, HashSet<string> seen)
	{
		if (string.IsNullOrEmpty(name))
			return;
		if (seen.Add(name))
			motionNames.Add(name);
	}

	private static string GetHierarchyPath(Transform t)
	{
		var parts = new List<string>();
		while (t != null)
		{
			parts.Add(t.name);
			t = t.parent;
		}
		parts.Reverse();
		return string.Join("/", parts);
	}

	private static int GetComponentIndex(AnimatorPlayer comp)
	{
		var comps = comp.GetComponents<AnimatorPlayer>();
		for (int i = 0; i < comps.Length; i++)
		{
			if (comps[i] == comp)
				return i;
		}
		return 0;
	}

	private static string Vec3(Vector3 v)
	{
		return v.x.ToString(CultureInfo.InvariantCulture) + "," +
			v.y.ToString(CultureInfo.InvariantCulture) + "," +
			v.z.ToString(CultureInfo.InvariantCulture);
	}

	private static string SanitizeFileName(string name)
	{
		foreach (char c in Path.GetInvalidFileNameChars())
			name = name.Replace(c, '_');
		return name;
	}
}
