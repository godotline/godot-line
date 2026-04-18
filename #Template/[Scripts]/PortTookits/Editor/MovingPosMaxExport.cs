using System;
using System.IO;
using System.Globalization;
using System.Text;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using MaxIceFlameTemplate.Animations;
using DG.Tweening;

public static class MovingPosMaxExport
{
	[MenuItem("Tools/Export MovingPosMax (Current Scene)")]
	public static void ExportCurrentScene()
	{
		string folder = EditorUtility.OpenFolderPanel("Export MovingPosMax", "", "");
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
			var comps = root.GetComponentsInChildren<MovingPosMax>(true);
			foreach (var comp in comps)
			{
				int componentIndex = GetComponentIndex(comp);
				string hierarchyPath = GetHierarchyPath(comp.transform);
				string fileName = SanitizeFileName(hierarchyPath.Replace("/", "_")) + "__" + componentIndex + ".mpm";
				string filePath = Path.Combine(folder, fileName);

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

				string animPath = comp.AnimationObject != null ? GetHierarchyPath(comp.AnimationObject.transform) : "";
				sb.AppendLine("animation_object_path=" + animPath);

				int count = comp.Position != null ? comp.Position.Length : 0;
				sb.AppendLine("positions_count=" + count.ToString(CultureInfo.InvariantCulture));
				for (int i = 0; i < count; i++)
				{
					var p = comp.Position[i];
					sb.AppendLine("position_" + i + "_pos=" + Vec3(p.Pos));
					sb.AppendLine("position_" + i + "_ease=" + ((int)p.Ease).ToString(CultureInfo.InvariantCulture));
					sb.AppendLine("position_" + i + "_ease_name=" + p.Ease.ToString());
					sb.AppendLine("position_" + i + "_postime=" + p.PosTime.ToString(CultureInfo.InvariantCulture));
					sb.AppendLine("position_" + i + "_waittime=" + p.WaitTime.ToString(CultureInfo.InvariantCulture));
				}

				File.WriteAllText(filePath, sb.ToString(), Encoding.UTF8);
				exported++;
			}
		}

		if (exported == 0)
			Debug.LogError("No MovingPosMax components found in current scene.");
		else
			Debug.Log("Exported " + exported + " MovingPosMax components to: " + folder);
	}

	private static string GetHierarchyPath(Transform t)
	{
		var parts = new System.Collections.Generic.List<string>();
		while (t != null)
		{
			parts.Add(t.name);
			t = t.parent;
		}
		parts.Reverse();
		return string.Join("/", parts);
	}

	private static int GetComponentIndex(MovingPosMax comp)
	{
		var comps = comp.GetComponents<MovingPosMax>();
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
