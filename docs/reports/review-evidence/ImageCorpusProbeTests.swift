@testable import CamCardReplica
import XCTest
import Foundation
import CoreGraphics
import ImageIO
final class ReviewCorpusProbeTests: XCTestCase {
 func testFullImageCorpusReviewProbe() throws {
  let data = try Data(contentsOf: URL(fileURLWithPath:"/Users/I783217/Projects/mobile-app-dev/cam-card-replica/TestData/ground-truth/ground_truth.json"))
  let json = try JSONSerialization.jsonObject(with:data) as! [String:Any]
  let cards = json["cards"] as! [[String:Any]]
  let detector = VisionCardDetector(), corrector = CoreImageCardCorrector(), recognizer = VisionTextRecognizer(), parser = HeuristicFieldParser()
  var counts: [String:(Int,Int)] = [:]
  var failures: [String] = []
  func norm(_ value: String?) -> String { (value ?? "").trimmingCharacters(in:.whitespacesAndNewlines).lowercased() }
  func check(_ kind:String, _ field:String, _ id:String, _ expected:[String], _ actual:[String]) {
   let key = kind+","+field
   let ok = expected.map{norm($0)}.sorted() == actual.map{norm($0)}.sorted()
   let old = counts[key] ?? (0,0); counts[key] = (old.0+(ok ? 1:0),old.1+1)
   if !ok { failures.append("\(id)|\(kind)|\(field)|expected=\(expected)|actual=\(actual)") }
  }
  for c in cards { try autoreleasepool {
   let file = c["file"] as! String, kind = c["kind"] as! String, id = c["id"] as! String
   let fields = c["fields"] as! [String:Any]
   let path = "/Users/I783217/Projects/mobile-app-dev/cam-card-replica/TestData/cards/"+file
   guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil), let image = CGImageSourceCreateImageAtIndex(source,0,nil) else { print("decode error: \(path)"); return }
   let quad = try? detector.detectCard(in:image,orientation:.up)
   let target = quad.flatMap { try? corrector.correct(image,quad:$0) } ?? image
   let parsed = parser.parse(try recognizer.recognize(image:target,orientation:.up))
   let values:[String:String?] = ["name":parsed.name?.value,"company":parsed.company?.value,"jobTitle":parsed.jobTitle?.value,"website":parsed.website?.value,"address":parsed.address?.value]
   for (field,actual) in values { check(kind,field,id,(fields[field] as? String).map{[$0]} ?? [],actual.map{[$0]} ?? []) }
   check(kind,"emails",id,fields["emails"] as? [String] ?? [],parsed.emails.map(\.value))
   let phones = fields["phones"] as? [[String:String]] ?? []
   for pk in ["mobile","office","fax"] { check(kind,pk,id,phones.filter{$0["kind"] == pk}.compactMap{$0["number"]},parsed.phones.filter{$0.kind.rawValue == pk}.map{$0.value.value}) }
  }
  }
  print("kind,field,correct,total,accuracy")
  for key in counts.keys.sorted() { let c = counts[key]!; print("\(key),\(c.0),\(c.1),\(String(format:"%.3f",Double(c.0)/Double(c.1)))") }
  print("FAILURES")
  for f in failures { print(f) }
 }
}
