// Repo-specific text for the shared pages (home cards, hero). Descriptions come from the README and the code.
export const SITE = {
  kicker: 'iOS · RoomPlan · ARKit · SwiftUI · SceneKit',
  lead: 'A native iOS app for scanning rooms with the iPhone LiDAR sensor: Apple\'s RoomPlan turns the scan into ' +
    'walls, doors, windows and furniture, shown live as a 3D model or a 2D floor plan, and each saved scan is exported ' +
    'as USD, USDZ and a JSON file for Python analysis. This site shows its Swift source and runs its export and ' +
    'floor-plan geometry in your browser.',
  cards: [
    ['#/code', 'Code explorer', 'Every Swift file with its header summary, outline and search.', 'a'],
    ['#/how', 'How it works', 'The RoomPlan session, the live 3D and 2D views, saving and the three export formats, with links into the source.', 'b'],
    ['#/demo', 'Floor-plan lab', 'Build a test room or open an exported scan: the app\'s floor-plan and JSON-export geometry, ported from Swift.', 'c'],
    ['#/about', 'About', 'What you need to build and run the real app in Xcode, and how to run this site.', 'a'],
  ],
};
