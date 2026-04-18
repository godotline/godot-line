using System;
using System.IO;
using System.Globalization;
using System.Text;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using MaxIceFlameTemplate.Camera;

public static class CameraTriggerExport
{
	[MenuItem("Tools/Export CameraTrigger (Current Scene)")]
	public static void ExportCurrentScene()
	{
		string folder = EditorUtility.OpenFolderPanel("Export CameraTrigger", "", "");
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
			var comps = root.GetComponentsInChildren<CameraTrigger>(true);
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

				string cameraPath = comp.SetCamera != null ? GetHierarchyPath(comp.SetCamera.transform) : "";
				sb.AppendLine("set_camera_path=" + cameraPath);

				sb.AppendLine("active_position=" + comp.ActivePosition.ToString());
				sb.AppendLine("new_add_position=" + Vec3(comp.NewAddPosition));
				sb.AppendLine("active_rotate=" + comp.ActiveRotate.ToString());
				sb.AppendLine("new_rotation=" + Vec3(comp.NewRotation));
				sb.AppendLine("active_distance=" + comp.ActiveDistance.ToString());
				sb.AppendLine("new_distance=" + comp.NewDistance.ToString(CultureInfo.InvariantCulture));
				sb.AppendLine("active_speed=" + comp.ActiveSpeed.ToString());
				sb.AppendLine("new_follow_speed=" + comp.NewFollowSpeed.ToString(CultureInfo.InvariantCulture));
				sb.AppendLine("ease_type=" + comp.Ease.ToString());
				sb.AppendLine("need_time=" + comp.NeedTime.ToString(CultureInfo.InvariantCulture));
				sb.AppendLine("use_time=" + comp.useTime.ToString());
				sb.AppendLine("trigger_time=" + comp.time.ToString(CultureInfo.InvariantCulture));

				File.WriteAllText(filePath, sb.ToString(), Encoding.UTF8);
				exported++;
			}
		}

		if (exported == 0)
			Debug.LogError("No CameraTrigger components found in current scene.");
		else
			Debug.Log("Exported " + exported + " CameraTrigger components to: " + folder);
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

	private static int GetComponentIndex(CameraTrigger comp)
	{
		var comps = comp.GetComponents<CameraTrigger>();
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
